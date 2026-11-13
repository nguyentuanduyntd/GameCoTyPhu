// Tỷ Phú Đất Việt — server online chạy trên Cloudflare Workers (gói miễn phí), 24/7.
//
// Đây là "trạm chuyển tiếp" (relay) cho chế độ lockstep: giữ phòng / mã phòng / chỗ ngồi, đánh số thứ tự
// nước đi và phát cho mọi máy, giữ đồng hồ (hết giờ, xử thua), cho người rớt mạng vào lại.
// Khác server Godot (scripts/net/game_server.gd): trạm KHÔNG chạy luật chơi —
//  - mỗi máy tự chạy GameEngine giống hệt nhau và báo lại (ready) lượt đang chờ ai + mã trạng thái;
//  - nước đi không hợp lệ bị mọi máy bỏ qua như nhau (vẫn khớp nhau);
//  - bot do máy của chủ phòng "đi hộ" (bot_turn), chủ phòng vắng thì máy người khác đi hộ;
//  - hết giờ: trạm phát {k:"timeout"}, mỗi máy tự áp phương án an toàn GameEngine.timeout_action().
// Giao thức JSON giống server Godot (xem docs/ONLINE.md), thêm: bot_turn, resync, move k=timeout.

const PROTOCOL = 1;
const CODE_CHARS = "ACDEFGHJKMNPQRTUVWXY234679";
const CODE_LEN = 6;
const MAX_SEATS = 6;
const MIN_SEATS = 2;
const THINK_TIME = 30;
const AUCTION_TIME = 12;
const OFFLINE_TIME = 5;
const MAX_STRIKES = 3;
const PRESENT_CAP = 20;
const BOT_DELAY = 0.35;
const BOT_WAIT = 8;
const EMPTY_TTL = 300;
const BOT_NAMES = ["Máy · An", "Máy · Bình", "Máy · Chi", "Máy · Dũng", "Máy · Em"];
const CHARACTERS = ["xe_om", "tieu_thuong", "tho_ho", "ngu_dan", "doanh_nhan", "hoc_sinh", "nong_dan", "nghe_si"];
const SERVER_NAME = "Server công cộng (Cloudflare)";

export default {
	async fetch(request, env) {
		if (request.headers.get("Upgrade") === "websocket") {
			const stub = env.LOBBY.get(env.LOBBY.idFromName("main"));
			return stub.fetch(request);
		}
		return new Response(
			"Tỷ Phú Đất Việt — server online đang chạy (kết nối bằng WebSocket).\n" +
			"Chơi ngay: https://nguyentuanduyntd.github.io/GameCoTyPhu/\n",
			{ headers: { "content-type": "text/plain; charset=utf-8" } });
	},
};

function now() { return Date.now() / 1000; }

function makeCode(taken) {
	let c;
	do {
		c = "";
		for (let i = 0; i < CODE_LEN; i++) c += CODE_CHARS[Math.floor(Math.random() * CODE_CHARS.length)];
	} while (taken.has(c));
	return c;
}

function clamp(v, a, b) { return Math.max(a, Math.min(b, v)); }

export class Lobby {
	constructor(state, env) {
		this.state = state;
		this.peers = new Map();   // id -> {ws, name, character, token, room, hello}
		this.rooms = new Map();   // code -> room
		this.nextId = 1;
		this.timer = null;
	}

	async fetch(request) {
		const pair = new WebSocketPair();
		const [client, server] = Object.values(pair);
		server.accept();
		const id = this.nextId++;
		this.peers.set(id, { ws: server, name: "", character: "", token: "", room: "", hello: false });
		server.addEventListener("message", (ev) => {
			let msg;
			try { msg = JSON.parse(typeof ev.data === "string" ? ev.data : new TextDecoder().decode(ev.data)); } catch { return; }
			if (msg && typeof msg === "object") this.handle(id, msg);
		});
		// máy kia chủ động đóng: phải đáp lại khung "close" để kết nối đóng hẳn (nếu không, máy kia kẹt ở
		// trạng thái đang đóng và không biết để kết nối lại)
		server.addEventListener("close", (ev) => {
			try { server.close(ev.code === 1005 || ev.code === 1006 ? 1000 : ev.code, "bye"); } catch { /* đã đóng */ }
			this.drop(id);
		});
		server.addEventListener("error", () => this.drop(id));
		if (!this.timer) this.timer = setInterval(() => this.tick(), 250);
		return new Response(null, { status: 101, webSocket: client });
	}

	send(id, msg) {
		const p = this.peers.get(id);
		if (!p) return;
		try { p.ws.send(JSON.stringify(msg)); } catch { /* đã đóng */ }
	}

	error(id, text) { this.send(id, { t: "error", text }); }

	// ------------------------------------------------------------------ phòng

	newRoom(code, options) {
		const r = {
			code, seats: [], host: 0,
			options: { rounds: 25, difficulty: 1, think: THINK_TIME },
			started: false, seed: 0, log: [],
			phase: "idle", phaseT: 0, limit: 0, turn: -1, ptype: "", driver: -1,
			ready: new Map(), hashes: new Map(), over: false, emptyT: 0,
		};
		this.setOptions(r, options || {});
		return r;
	}

	setOptions(r, o) {
		if ("rounds" in o) r.options.rounds = clamp(Math.round(Number(o.rounds) || 25), 5, 60);
		if ("difficulty" in o) {
			r.options.difficulty = clamp(Math.round(Number(o.difficulty) || 0), 0, 2);
			for (const s of r.seats) if (s.is_bot) s.difficulty = r.options.difficulty;
		}
		if ("think" in o) r.options.think = clamp(Number(o.think) || THINK_TIME, 3, 120);
	}

	freeCharacter(r, want) {
		const used = new Set(r.seats.map((s) => s.character));
		if (want && !used.has(want)) return want;
		return CHARACTERS.find((c) => !used.has(c)) || want || CHARACTERS[0];
	}

	uniqueName(r, name) {
		name = String(name || "").trim().slice(0, 18) || "Người chơi";
		const base = name;
		let k = 2;
		while (r.seats.some((s) => s.name === name)) name = `${base} ${k++}`;
		return name;
	}

	addHuman(r, id, info) {
		if (r.seats.length >= MAX_SEATS) return -1;
		r.seats.push({ name: this.uniqueName(r, info.name), character: this.freeCharacter(r, info.character),
			is_bot: false, difficulty: 1, token: info.token, peer: id, connected: true, strikes: 0 });
		return r.seats.length - 1;
	}

	addBot(r) {
		if (r.seats.length >= MAX_SEATS) return false;
		const used = new Set(r.seats.map((s) => s.name));
		const name = BOT_NAMES.find((n) => !used.has(n)) || "Máy";
		r.seats.push({ name, character: this.freeCharacter(r, ""), is_bot: true, difficulty: r.options.difficulty,
			token: "", peer: 0, connected: true, strikes: 0 });
		return true;
	}

	removeSeat(r, i) {
		if (i < 0 || i >= r.seats.length) return;
		r.seats.splice(i, 1);
		if (r.host === i || r.host >= r.seats.length) {
			const h = r.seats.findIndex((s) => !s.is_bot);
			r.host = h >= 0 ? h : 0;
		} else if (r.host > i) {
			r.host -= 1;
		}
	}

	seatOfPeer(r, id) { return r.seats.findIndex((s) => s.peer === id); }
	seatOfToken(r, token) { return token ? r.seats.findIndex((s) => !s.is_bot && s.token === token) : -1; }
	humansConnected(r) { return r.seats.filter((s) => !s.is_bot && s.connected).length; }

	configs(r) {
		return r.seats.map((s) => ({ name: s.name, character: s.character, is_bot: s.is_bot, difficulty: s.difficulty }));
	}

	roomState(r, you) {
		return { t: "room", code: r.code, host: r.host, you,
			seats: r.seats.map((s) => ({ name: s.name, character: s.character, is_bot: s.is_bot, connected: s.connected })),
			options: r.options, started: r.started };
	}

	broadcastRoom(r) {
		r.seats.forEach((s, i) => { if (!s.is_bot && s.connected) this.send(s.peer, this.roomState(r, i)); });
	}

	broadcast(r, msg) {
		for (const s of r.seats) if (!s.is_bot && s.connected) this.send(s.peer, msg);
	}

	startMessage(r, seat) {
		return { t: "start", seed: r.seed, configs: this.configs(r), rounds: r.options.rounds, seat,
			think: r.options.think, log: r.log, hash: "", relay: true };
	}

	openRooms() {
		const out = [];
		for (const r of this.rooms.values()) {
			if (r.started || r.seats.length >= MAX_SEATS || r.seats.length === 0) continue;
			const host = r.seats[clamp(r.host, 0, r.seats.length - 1)].name;
			out.push({ code: r.code, host, seats: r.seats.length, max: MAX_SEATS });
		}
		return out;
	}

	// ------------------------------------------------------------------ ván chơi

	startGame(r) {
		if (r.started) return "Ván đã bắt đầu.";
		if (r.seats.length < MIN_SEATS) return `Cần ít nhất ${MIN_SEATS} người chơi (có thể thêm máy).`;
		r.started = true;
		r.seed = 1 + Math.floor(Math.random() * 2147483645);
		r.log = [];
		r.ready = new Map();
		r.hashes = new Map();
		r.over = false;
		for (const s of r.seats) s.strikes = 0;
		this.enterPresent(r);
		r.seats.forEach((s, i) => { if (!s.is_bot && s.connected) this.send(s.peer, this.startMessage(r, i)); });
		return "";
	}

	enterPresent(r) { r.phase = "present"; r.phaseT = 0; }

	record(r, entry) {
		r.log.push(entry);
		this.broadcast(r, { t: "move", n: r.log.length, ...entry });
		this.enterPresent(r);
	}

	// Lượt đang chờ ai (theo báo cáo của các máy sau nước thứ n = log.length)
	reportsNow(r) {
		const n = r.log.length;
		const reps = [];
		for (const [seat, rep] of r.ready) {
			const s = r.seats[seat];
			if (s && !s.is_bot && s.connected && rep.n === n) reps.push(rep);
		}
		return reps;
	}

	allReady(r) {
		const n = r.log.length;
		return r.seats.every((s, i) => s.is_bot || !s.connected || (r.ready.get(i) && r.ready.get(i).n >= n));
	}

	pickDriver(r) {
		const host = r.seats[r.host];
		if (host && !host.is_bot && host.connected) return r.host;
		return r.seats.findIndex((s) => !s.is_bot && s.connected);
	}

	tick() {
		const dt = 0.25;
		for (const [code, r] of this.rooms) {
			if (this.humansConnected(r) === 0) {
				r.emptyT += dt;
				if (r.emptyT >= EMPTY_TTL || !r.started) { this.rooms.delete(code); continue; }
			} else {
				r.emptyT = 0;
			}
			if (!r.started || r.over) continue;
			r.phaseT += dt;
			if (r.phase === "present") {
				const reps = this.reportsNow(r);
				if (reps.length === 0) continue;
				if (!(this.allReady(r) || r.phaseT >= PRESENT_CAP)) continue;
				const rep = reps[0];
				if (rep.over) { r.over = true; r.phase = "over"; continue; }
				r.turn = rep.turn;
				r.ptype = rep.ptype;
				const s = r.seats[r.turn];
				if (!s) continue;
				if (s.is_bot) {
					r.phase = "botwait";
					r.phaseT = 0;
				} else {
					r.phase = "think";
					r.phaseT = 0;
					r.limit = !s.connected ? OFFLINE_TIME : (r.ptype === "auction_bid" ? AUCTION_TIME : r.options.think);
					this.broadcast(r, { t: "timer", p: r.turn, secs: r.limit, n: r.log.length });
				}
			} else if (r.phase === "botwait") {
				if (r.phaseT >= BOT_DELAY) {
					r.driver = this.pickDriver(r);
					r.phase = "bot";
					r.phaseT = 0;
					this.broadcast(r, { t: "bot_turn", p: r.turn, n: r.log.length, driver: r.driver });
				}
			} else if (r.phase === "bot") {
				if (r.phaseT >= BOT_WAIT) this.record(r, { k: "timeout", p: r.turn });
			} else if (r.phase === "think") {
				if (r.phaseT >= r.limit) this.onTimeout(r);
			}
		}
		if (this.rooms.size === 0 && this.peers.size === 0 && this.timer) {
			clearInterval(this.timer);
			this.timer = null;
		}
	}

	onTimeout(r) {
		const pid = r.turn;
		const s = r.seats[pid];
		s.strikes += 1;
		if (s.strikes >= MAX_STRIKES) {
			this.broadcast(r, { t: "notice", text: `${s.name} vắng mặt ${MAX_STRIKES} lượt liên tiếp — bị loại.` });
			this.record(r, { k: "forfeit", p: pid });
			return;
		}
		this.broadcast(r, { t: "notice", text: `${s.name} hết giờ (${s.strikes}/${MAX_STRIKES}).` });
		this.record(r, { k: "timeout", p: pid });
	}

	currentWait(r, seat) {
		if (r.phase === "think") return { t: "timer", p: r.turn, secs: Math.max(r.limit - r.phaseT, 0), n: r.log.length };
		if (r.phase === "bot") return { t: "bot_turn", p: r.turn, n: r.log.length, driver: r.driver };
		return null;
	}

	// ------------------------------------------------------------------ kết nối

	drop(id) {
		const info = this.peers.get(id);
		if (!info) return;
		this.peers.delete(id);
		const r = this.rooms.get(info.room);
		if (!r) return;
		const seat = this.seatOfPeer(r, id);
		if (seat < 0) return;
		if (!r.started) {
			this.removeSeat(r, seat);
			this.broadcastRoom(r);
		} else {
			r.seats[seat].connected = false;
			r.seats[seat].peer = 0;
			r.ready.delete(seat);
			this.broadcast(r, { t: "presence", seat, connected: false });
			if (r.phase === "bot" && r.driver === seat) {   // người đi hộ bot rớt mạng: giao cho người khác
				r.driver = this.pickDriver(r);
				r.phaseT = 0;
				this.broadcast(r, { t: "bot_turn", p: r.turn, n: r.log.length, driver: r.driver });
			}
		}
	}

	leave(id) {
		const info = this.peers.get(id);
		if (!info) return;
		const r = this.rooms.get(info.room);
		info.room = "";
		this.send(id, { t: "left" });
		if (!r) return;
		const seat = this.seatOfPeer(r, id);
		if (seat < 0) return;
		if (r.started) {
			r.seats[seat].connected = false;
			r.seats[seat].peer = 0;
			r.ready.delete(seat);
			this.broadcast(r, { t: "presence", seat, connected: false });
		} else {
			this.removeSeat(r, seat);
			this.broadcastRoom(r);
		}
	}

	handle(id, msg) {
		const t = String(msg.t || "");
		const info = this.peers.get(id);
		if (!info) return;
		if (t === "ping") { this.send(id, { t: "pong" }); return; }
		if (t === "hello") {
			if (Number(msg.v) !== PROTOCOL) {
				this.error(id, `Phiên bản game khác server (server v${PROTOCOL}). Hãy cập nhật game.`);
				return;
			}
			info.name = String(msg.name || "Người chơi").slice(0, 18);
			info.character = String(msg.character || "");
			info.token = String(msg.token || "").slice(0, 64);
			info.hello = true;
			this.send(id, { t: "welcome", v: PROTOCOL, relay: true });
			return;
		}
		if (!info.hello) { this.error(id, "Chưa chào server."); return; }
		const room = this.rooms.get(info.room);
		switch (t) {
			case "list_rooms":
				this.send(id, { t: "rooms", rooms: this.openRooms(), name: SERVER_NAME });
				break;
			case "create_room": {
				if (room) this.leave(id);
				const code = makeCode(new Set(this.rooms.keys()));
				const r = this.newRoom(code, msg.options);
				this.rooms.set(code, r);
				this.addHuman(r, id, info);
				r.host = 0;
				info.room = code;
				this.broadcastRoom(r);
				break;
			}
			case "join_room": {
				const code = String(msg.code || "").trim().toUpperCase();
				const r = this.rooms.get(code);
				if (!r) { this.error(id, `Không tìm thấy phòng ${code}.`); return; }
				if (room && room.code !== code) this.leave(id);
				const seat = this.seatOfToken(r, info.token);
				if (r.started) {
					if (seat < 0) { this.error(id, `Phòng ${code} đã vào ván.`); return; }
					const old = r.seats[seat].peer;
					if (old && old !== id && this.peers.has(old)) {
						this.peers.get(old).room = "";
						try { this.peers.get(old).ws.close(1000, "vao lai"); } catch { /* */ }
					}
					info.room = code;
					r.seats[seat].connected = true;
					r.seats[seat].peer = id;
					r.seats[seat].strikes = 0;
					r.ready.delete(seat);
					this.broadcast(r, { t: "presence", seat, connected: true });
					this.send(id, this.roomState(r, seat));
					this.send(id, this.startMessage(r, seat));
					const w = this.currentWait(r, seat);
					if (w) this.send(id, w);
					return;
				}
				if (seat >= 0) {
					r.seats[seat].peer = id;
					r.seats[seat].connected = true;
				} else if (this.addHuman(r, id, info) < 0) {
					this.error(id, `Phòng ${code} đã đủ ${MAX_SEATS} người.`);
					return;
				}
				info.room = code;
				this.broadcastRoom(r);
				break;
			}
			case "leave_room":
				this.leave(id);
				break;
			case "set_character": {
				if (!room || room.started) return;
				const seat = this.seatOfPeer(room, id);
				const ch = String(msg.character || "");
				if (!CHARACTERS.includes(ch) || room.seats.some((s, i) => i !== seat && s.character === ch)) {
					this.error(id, "Nhân vật này đã có người chọn.");
				} else if (seat >= 0) {
					room.seats[seat].character = ch;
				}
				this.broadcastRoom(room);
				break;
			}
			case "add_bot": case "remove_bot": case "set_options": case "start_game": {
				if (!room || room.started) return;
				if (this.seatOfPeer(room, id) !== room.host) { this.error(id, "Chỉ chủ phòng làm được việc này."); return; }
				if (t === "add_bot") {
					if (!this.addBot(room)) this.error(id, "Phòng đã đủ người.");
				} else if (t === "remove_bot") {
					const s = Number(msg.seat);
					if (s >= 0 && s < room.seats.length && room.seats[s].is_bot) this.removeSeat(room, s);
				} else if (t === "set_options") {
					this.setOptions(room, msg.options || {});
				} else {
					const err = this.startGame(room);
					if (err) { this.error(id, err); return; }
				}
				this.broadcastRoom(room);
				break;
			}
			case "action": {
				if (!room || !room.started || room.over) return;
				const seat = this.seatOfPeer(room, id);
				const a = msg.a && typeof msg.a === "object" ? msg.a : {};
				const forBot = "for" in msg ? Number(msg.for) : -1;
				if (a.action === "skip") { this.send(id, { t: "reject", text: "Hành động không hợp lệ.", n: room.log.length }); return; }
				if (room.phase === "think" && seat === room.turn && forBot < 0) {
					room.seats[seat].strikes = 0;
					this.record(room, { k: "act", p: seat, a });
				} else if (room.phase === "bot" && seat === room.driver && forBot === room.turn) {
					this.record(room, { k: "act", p: room.turn, a });
				} else {
					this.send(id, { t: "reject", text: "Chưa tới lượt bạn.", n: room.log.length });
				}
				break;
			}
			case "ready": {
				if (!room || !room.started) return;
				const seat = this.seatOfPeer(room, id);
				if (seat < 0) return;
				const n = Number(msg.n) || 0;
				room.ready.set(seat, { n, turn: Number(msg.turn), ptype: String(msg.ptype || ""), over: !!msg.over });
				// so mã trạng thái giữa các máy: máy nào lệch thì cho tải lại ván
				const h = String(msg.h || "");
				if (h) {
					const first = room.hashes.get(n);
					if (first === undefined) {
						room.hashes.set(n, h);
						for (const k of room.hashes.keys()) if (k < n - 5) room.hashes.delete(k);
					} else if (first !== h) {
						this.send(id, { t: "resync" });
					}
				}
				break;
			}
		}
	}
}
