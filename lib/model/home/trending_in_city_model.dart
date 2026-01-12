class TrendingInCity {
  bool? success;
  List<Data>? data;

  TrendingInCity({this.success, this.data});

  TrendingInCity.fromJson(Map<String, dynamic> json) {
    success = json['success'];
    if (json['data'] != null) {
      data = <Data>[];
      json['data'].forEach((v) {
        data!.add(new Data.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['success'] = this.success;
    if (this.data != null) {
      data['data'] = this.data!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Data {
  String? sId;
  String? label;
  List<Items>? items;
  Pagination? pagination;

  Data({this.sId, this.label, this.items, this.pagination});

  Data.fromJson(Map<String, dynamic> json) {
    sId = json['_id'];
    label = json['label'];
    if (json['items'] != null) {
      items = <Items>[];
      json['items'].forEach((v) {
        items!.add(new Items.fromJson(v));
      });
    }
    pagination = json['pagination'] != null
        ? new Pagination.fromJson(json['pagination'])
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['_id'] = this.sId;
    data['label'] = this.label;
    if (this.items != null) {
      data['items'] = this.items!.map((v) => v.toJson()).toList();
    }
    if (this.pagination != null) {
      data['pagination'] = this.pagination!.toJson();
    }
    return data;
  }
}

class Items {
  String? sId;
  String? itemName;
  String? brand;
  int? salesPrice;
  int? mrp;
  List<String>? itemImages;
  int? currentStock;

  Items({
    this.sId,
    this.itemName,
    this.brand,
    this.salesPrice,
    this.mrp,
    this.itemImages,
    this.currentStock,
  });

  Items.fromJson(Map<String, dynamic> json) {
    sId = json['_id'];
    itemName = json['itemName'];
    brand = json['brand'];
    salesPrice = json['salesPrice'];
    mrp = json['mrp'];
    itemImages = json['itemImages']?.cast<String>() ?? [];
    currentStock = json['currentStock'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['_id'] = sId;
    data['itemName'] = itemName;
    data['brand'] = brand;
    data['salesPrice'] = salesPrice;
    data['mrp'] = mrp;
    data['itemImages'] = itemImages;
    data['currentStock'] = currentStock;
    return data;
  }
}
class Pagination {
  int? page;
  int? limit;
  int? total;
  int? pages;

  Pagination({this.page, this.limit, this.total, this.pages});

  Pagination.fromJson(Map<String, dynamic> json) {
    page = json['page'];
    limit = json['limit'];
    total = json['total'];
    pages = json['pages'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['page'] = this.page;
    data['limit'] = this.limit;
    data['total'] = this.total;
    data['pages'] = this.pages;
    return data;
  }
}
