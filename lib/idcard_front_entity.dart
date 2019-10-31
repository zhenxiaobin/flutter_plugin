class IdcardFrontEntity {
	String cardImageFontPath;
	String idCardName;
	String idCardBirth;
	String idCardAddress;
	String idCardNum;

	IdcardFrontEntity({this.cardImageFontPath, this.idCardAddress, this.idCardNum, this.idCardName, this.idCardBirth});

	IdcardFrontEntity.fromJson(Map<String, dynamic> json) {
		cardImageFontPath = json['cardImageFontPath'];
		idCardAddress = json['idCardAddress'];
		idCardNum = json['idCardNum'];
		idCardName = json['idCardName'];
		idCardBirth = json['idCardBirth'];
	}

	Map<String, dynamic> toJson() {
		final Map<String, dynamic> data = new Map<String, dynamic>();
		data['cardImageFontPath'] = this.cardImageFontPath;
		data['idCardAddress'] = this.idCardAddress;
		data['idCardNum'] = this.idCardNum;
		data['idCardName'] = this.idCardName;
		data['idCardBirth'] = this.idCardBirth;
		return data;
	}
}
