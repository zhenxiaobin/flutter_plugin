class IdcardBackEntity {
	String idCardExpDate;//有效期
	String cardImageBackPath;//图片路径
	String idCardIssuingAuthority;//签发机关

	IdcardBackEntity({this.idCardExpDate, this.cardImageBackPath, this.idCardIssuingAuthority});

	IdcardBackEntity.fromJson(Map<String, dynamic> json) {
		idCardExpDate = json['idCardExpDate'];
		cardImageBackPath = json['cardImageBackPath'];
		idCardIssuingAuthority = json['idCardIssuingAuthority'];
	}

	Map<String, dynamic> toJson() {
		final Map<String, dynamic> data = new Map<String, dynamic>();
		data['idCardExpDate'] = this.idCardExpDate;
		data['cardImageBackPath'] = this.cardImageBackPath;
		data['idCardIssuingAuthority'] = this.idCardIssuingAuthority;
		return data;
	}
}
