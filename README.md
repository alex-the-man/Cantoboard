# Cantoboard
iOS 嘅智能廣東話鍵盤 Smart Cantonese Keyboard on iOS

## Demo
TODO 加入圖片宣傳輸入法

## 特點
- Support 多隻輸入法: 粵拼, 耶魯, 速成, 倉頡, 筆劃同埋普通話拼音. 
- 全部輸入法皆有學習功能, 會記住你打過嘅詞彙. 使用 Rime 輸入引擎. 學習完全離線, 唔會 share 任何個人數據去 cloud.
- 大部份輸入法都 support 詞組輸入, 唔使逐隻字打. 內置詞庫包含廣東話常用詞組.
- 候選字會自動根據使用頻率排序. 內置字頻根據香港人常用習慣. 廣東字例如 "嘅", "咁"唔會排後.
- 可以幫助使用者學習粵拼, 用唔同輸入法打字嘅時候係候選詞下面顯示粵拼. 因爲耶魯拼音缺乏一啲韻母, 如果要學, 建議學習粵拼, 粵拼先可以最準確表示字音.
- 粵拼同耶魯模式可以打聲調幫助選字.
- 如果候選字太多, 本輸入法同 iOS 內置中文輸入法一樣, 可以喺候選詞表向上拉, 根據部首, 筆劃或者粵拼排列候選字.
- 唔使轉輸入法都可以混打中英文. 打英文嘅時候有 auto correct 功能.
- 中英文輸入皆具智能輸入及糾錯功能. 標點符號會自動根據前文選擇半形/全形.
- 英文輸入方式模仿 iOS 系統鍵盤. Double tap 空格會輸入句號, 識自動判斷大細楷.
- 長按符號鍵會顯示所有全形半形選擇.

## Download
[![Get it on App Store](https://user-images.githubusercontent.com/8400790/130535947-be7cf192-77c7-46da-827b-a8b92f9b76ff.png)](https://apps.apple.com/us/app/cantoboard/id1556817074)

App Store QR code:

![Cantoboard on App Store](https://user-images.githubusercontent.com/8400790/130536100-c1374acf-2662-44d2-a83c-13849722670c.png)

[Get Beta build on TestFlight](https://testflight.apple.com/join/zq9YSjuv)

TestFlight QR code:

![Cantoboard Beta on TestFlight](https://user-images.githubusercontent.com/8400790/130536005-86aeacbc-4be9-43fe-ac49-dcf688eb4f40.png)

## FAQ
### 輸入法可以 support hardware keyboard 嗎?
因為 Apple API 唔容許 Keyboard Extension 接收 hardware keyboard 打字嘅events, 係 Apple 開放 API 之前, 唔可能 support hardware keyboard.

技術細節: 係 Keyboard Extension 入面, iOS 唔會 call 呢個 [handler](https://developer.apple.com/documentation/gamecontroller/gckeyboardinput/3626180-keychangedhandler).

## Credits
- [librime RIME: Rime Input Method Engine](https://github.com/rime/librime) BSD-3-Clause License
- [rime-cantonese Rime 粵語拼音方案](https://github.com/rime/rime-cantonese) Open Data Commons Open Database License
