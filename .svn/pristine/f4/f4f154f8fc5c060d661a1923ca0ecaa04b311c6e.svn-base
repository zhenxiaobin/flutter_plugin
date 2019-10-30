class IdcardFrontEntity {
	String path;
	String address;
	String code;
	String name;
	String birth;

	IdcardFrontEntity({this.path, this.address, this.code, this.name, this.birth});

	IdcardFrontEntity.fromJson(Map<String, dynamic> json) {
		path = json['path'];
		address = json['address'];
		code = json['code'];
		name = json['name'];
		birth = json['birth'];
	}

	Map<String, dynamic> toJson() {
		final Map<String, dynamic> data = new Map<String, dynamic>();
		data['path'] = this.path;
		data['address'] = this.address;
		data['code'] = this.code;
		data['name'] = this.name;
		data['birth'] = this.birth;
		return data;
	}
}
