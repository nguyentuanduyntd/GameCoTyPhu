class_name BuildingType
extends Resource
## Một loại công trình trên ô tỉnh thành (chỉnh trong data/buildings/*.tres).
## Mảng theo cấp: phần tử 0 = cấp 1 (nhà nhỏ), 1 = cấp 2 (nhà lớn), 2 = cấp 3 (Danh Thắng).

@export var id: String = ""
@export var name: String = ""
## Mô tả ngắn hiển thị trên thẻ chọn công trình.
@export_multiline var desc: String = ""
@export var color: Color = Color.WHITE
## Chi phí xây từng cấp × giá đất.
@export var build_mult: Array[float] = [0.6, 0.8, 1.2]
## Tiền thuê từng cấp × giá đất (trước các hệ số vùng, lễ hội, mùa...).
@export var rent_mult: Array[float] = [1.0, 2.2, 4.5]
## Homestay: thu nhập thụ động × giá đất mỗi khi chủ đi qua Km 0.
@export var lap_income: Array[float] = [0.0, 0.0, 0.0]
## Chợ: phí vào chợ × giá đất mỗi khi người khác đi qua hoặc dừng ở ô.
@export var pass_fee: Array[float] = [0.0, 0.0, 0.0]
## Chợ: phần phí chủ nhận, phần còn lại vào Quỹ Từ Thiện.
@export var fee_owner_share: float = 0.6
## Xưởng đặc sản: số đặc sản của tỉnh chủ nhận mỗi vòng mới.
@export var specialties_per_round: Array[int] = [0, 0, 0]
## Thưởng tiền thuê trong mùa Xuân – Tết.
@export var tet_rent_bonus: float = 0.0


func at(arr: Array, level: int) -> float:
	if level < 1 or arr.is_empty():
		return 0.0
	return float(arr[mini(level - 1, arr.size() - 1)])
