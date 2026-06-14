import 'package:flutter/material.dart';

class UserData {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String nickName;
  final String profileImage;
  final int    buspoints;
  final String fcmToken;

  const UserData({
    this.uid          = '',
    this.name         = '',
    this.email        = '',
    this.phone        = '',
    this.nickName     = '',
    this.profileImage = '',
    this.buspoints    = 0,
    this.fcmToken     = '',
  });

  UserData copyWith({
    String? uid,
    String? name,
    String? email,
    String? phone,
    String? nickName,
    String? profileImage,
    int?    buspoints,
    String? fcmToken,
  }) {
    return UserData(
      uid:          uid          ?? this.uid,
      name:         name         ?? this.name,
      email:        email        ?? this.email,
      phone:        phone        ?? this.phone,
      nickName:     nickName     ?? this.nickName,
      profileImage: profileImage ?? this.profileImage,
      buspoints:    buspoints    ?? this.buspoints,
      fcmToken:     fcmToken     ?? this.fcmToken,
    );
  }
}

class UserState extends InheritedWidget {
  final UserData data;
  final void Function(UserData) onUpdate;

  const UserState({
    super.key,
    required this.data,
    required this.onUpdate,
    required super.child,
  });

  static UserState? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<UserState>();

  @override
  bool updateShouldNotify(UserState oldWidget) => data != oldWidget.data;
}