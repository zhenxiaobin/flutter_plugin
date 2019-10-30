class IdcardBackEntity {
	String date;
	String path;
	String agentname;

	IdcardBackEntity({this.date, this.path, this.agentname});

	IdcardBackEntity.fromJson(Map<String, dynamic> json) {
		date = json['date'];
		path = json['path'];
		agentname = json['agentname'];
	}

	Map<String, dynamic> toJson() {
		final Map<String, dynamic> data = new Map<String, dynamic>();
		data['date'] = this.date;
		data['path'] = this.path;
		data['agentname'] = this.agentname;
		return data;
	}
}
