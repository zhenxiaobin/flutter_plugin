class BankcardEntity {
	String path;
	String bankcard;

	BankcardEntity({this.path, this.bankcard});

	BankcardEntity.fromJson(Map<String, dynamic> json) {
		path = json['path'];
		bankcard = json['bankcard'];
	}

	Map<String, dynamic> toJson() {
		final Map<String, dynamic> data = new Map<String, dynamic>();
		data['path'] = this.path;
		data['bankcard'] = this.bankcard;
		return data;
	}
}
