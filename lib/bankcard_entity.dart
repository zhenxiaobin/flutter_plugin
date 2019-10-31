class BankcardEntity {
	String bankCardImgPath;//图片路径
	String bankCardNo;//银行卡号

	BankcardEntity({this.bankCardImgPath, this.bankCardNo});

	BankcardEntity.fromJson(Map<String, dynamic> json) {
		bankCardImgPath = json['bankCardImgPath'];
		bankCardNo = json['bankCardNo'];
	}

	Map<String, dynamic> toJson() {
		final Map<String, dynamic> data = new Map<String, dynamic>();
		data['bankCardImgPath'] = this.bankCardImgPath;
		data['bankCardNo'] = this.bankCardNo;
		return data;
	}
}
