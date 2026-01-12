// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserModelAdapter extends TypeAdapter<UserModel> {
  @override
  final int typeId = 0;

  @override
  UserModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserModel(
      phone: fields[0] as String,
      name: fields[1] as String?,
      email: fields[2] as String?,
      city: fields[3] as String?,
      state: fields[4] as String?,
      country: fields[5] as String?,
      token: fields[6] as String?,
      isLoggedIn: fields[7] as bool,
      createdAt: fields[8] as DateTime?,
      id: fields[9] as String?,
      selectedWarehouseId: fields[10] as String?,
      estimatedDeliveryTime: fields[11] as int?,
      isServiceable: fields[12] as bool?,
      userLatitude: fields[13] as double?,
      userLongitude: fields[14] as double?,
      userAddress: fields[15] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, UserModel obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.phone)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.email)
      ..writeByte(3)
      ..write(obj.city)
      ..writeByte(4)
      ..write(obj.state)
      ..writeByte(5)
      ..write(obj.country)
      ..writeByte(6)
      ..write(obj.token)
      ..writeByte(7)
      ..write(obj.isLoggedIn)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.id)
      ..writeByte(10)
      ..write(obj.selectedWarehouseId)
      ..writeByte(11)
      ..write(obj.estimatedDeliveryTime)
      ..writeByte(12)
      ..write(obj.isServiceable)
      ..writeByte(13)
      ..write(obj.userLatitude)
      ..writeByte(14)
      ..write(obj.userLongitude)
      ..writeByte(15)
      ..write(obj.userAddress);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
