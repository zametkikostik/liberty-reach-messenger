name: liberty_reach_messenger
description: "A secure, decentralized messenger - Liberty Reach."
publish_to: 'none'
version: 0.4.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.6
  
  # Пакеты для работы ApiService
  http: ^1.1.0
  flutter_secure_storage: ^9.0.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0

flutter:
  uses-material-design: true

  # Если у тебя будут свои иконки или шрифты, добавим их ниже
