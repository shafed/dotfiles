import QtQml

QtObject {
  readonly property string barFont: "Inter"
  readonly property string bodyFont: "monospace"
  readonly property string sansFont: "sans-serif"
  readonly property color overlayColor: "#99000000"

  readonly property int barHeight: 30
  readonly property int barMargin: 4
  readonly property int barSpacing: 3
  readonly property int barItemSpacing: 1
  readonly property int barFontSize: 14
  readonly property int barButtonHeight: 28
  readonly property int barButtonMinWidth: 28
  readonly property int barButtonPadding: 14
  readonly property int barButtonRadius: 4
  readonly property int titleMaxWidth: 520
  readonly property real titleWidthRatio: 0.45

  readonly property int panelTopMargin: 34
  readonly property int panelRightMargin: 6
  readonly property int panelOuterGap: 12
  readonly property int panelWidth: 430
  readonly property int panelHeight: 560
  readonly property int systemOverviewHeight: 360
  readonly property int panelPadding: 14
  readonly property int panelSpacing: 8
  readonly property int panelRadius: 8
  readonly property int panelButtonHeight: 36
  readonly property int panelButtonRadius: 5
  readonly property int panelButtonTextSize: 12
  readonly property int panelButtonTextMargin: 12
  readonly property int headingSize: 13

  readonly property int pickerMaxWidth: 720
  readonly property int pickerMaxHeight: 600
  readonly property int pickerHorizontalInset: 80
  readonly property int pickerVerticalInset: 100
  readonly property int pickerRadius: 10
  readonly property int pickerPadding: 16
  readonly property int pickerSpacing: 10
  readonly property int pickerInputHeight: 38
  readonly property int pickerInputRadius: 6
  readonly property int pickerRowHeight: 54
  readonly property int pickerRowRadius: 7
  readonly property int pickerTitleSize: 15
  readonly property int pickerInputTextSize: 13
  readonly property int pickerHintSize: 12
  readonly property int pickerRowTitleSize: 13
  readonly property int pickerRowSubtitleSize: 11
  readonly property int pickerFooterSize: 10

  readonly property int clipboardMaxWidth: 760
  readonly property int clipboardMaxHeight: 620
  readonly property int clipboardHorizontalInset: 80
  readonly property int clipboardVerticalInset: 100

  readonly property int toastWidth: 390
  readonly property int toastMaxHeight: 520
  readonly property int toastTopMargin: 36
  readonly property int toastRightMargin: 8

  readonly property int osdWidth: 330
  readonly property int osdHeight: 76
  readonly property int osdBottomMargin: 70
  readonly property int osdTimeoutMs: 1300
  readonly property int toastTimeoutMs: 8000
  readonly property int fullRefreshMs: 15000
  readonly property int brightnessPollMs: 150
  readonly property int clockRefreshMs: 30000
}
