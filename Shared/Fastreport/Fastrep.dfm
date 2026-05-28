object ReportForm: TReportForm
  OnCreate = FormCreate
  Height = 444
  Width = 1032
  object FastReport: TfrxReport
    Version = '2025.1.1'
    DotMatrixReport = False
    EngineOptions.SilentMode = True
    EngineOptions.NewSilentMode = simSilent
    IniFile = '\Software\Fast Reports'
    PreviewOptions.Buttons = [pbPrint, pbLoad, pbSave, pbExport, pbZoom, pbFind, pbOutline, pbPageSetup, pbTools, pbEdit, pbNavigator, pbExportQuick, pbCopy, pbSelection]
    PreviewOptions.Zoom = 1.000000000000000000
    PrintOptions.Printer = 'Default'
    PrintOptions.PrintOnSheet = 0
    PrintOptions.ShowDialog = False
    ReportOptions.CreateDate = 44615.690910844910000000
    ReportOptions.LastChange = 44615.690910844910000000
    ScriptLanguage = 'PascalScript'
    ScriptText.Strings = (
      'begin'
      ''
      'end.')
    OnBeginDoc = FastReportBeginDoc
    Left = 64
    Top = 40
    Datasets = <>
    Variables = <>
    Style = <>
    object Data: TfrxDataPage
      Height = 1000.000000000000000000
      Width = 1000.000000000000000000
    end
    object Page1: TfrxReportPage
      PaperWidth = 210.000000000000000000
      PaperHeight = 297.000000000000000000
      PaperSize = 9
      LeftMargin = 10.000000000000000000
      RightMargin = 10.000000000000000000
      TopMargin = 10.000000000000000000
      BottomMargin = 10.000000000000000000
      Frame.Typ = []
      MirrorMode = []
    end
  end
  object frxDBDataset1: TfrxDBDataset
    UserName = 'frxDBDataset1'
    CloseDataSource = False
    BCDToCurrency = False
    DataSetOptions = []
    Left = 384
    Top = 40
  end
  object frxPDFExport1: TfrxPDFExport
    UseFileCache = True
    ShowProgress = True
    OverwritePrompt = False
    DataOnly = False
    EmbedFontsIfProtected = False
    InteractiveFormsFontSubset = 'A-Z,a-z,0-9,#43-#47 '
    OpenAfterExport = False
    PrintOptimized = False
    Outline = False
    Background = True
    HTMLTags = True
    Quality = 95
    Author = 'FastReport'
    Subject = 'FastReport PDF export'
    Creator = 'FastReport'
    ProtectionFlags = [ePrint, eModify, eCopy, eAnnot]
    HideToolbar = False
    HideMenubar = False
    HideWindowUI = False
    FitWindow = False
    CenterWindow = False
    PrintScaling = False
    PdfA = False
    PDFStandard = psNone
    PDFVersion = pv17
    Left = 484
    Top = 40
  end
  object frxGradientObject1: TfrxGradientObject
    Left = 48
    Top = 120
  end
  object frxDialogControls1: TfrxDialogControls
    Left = 184
    Top = 120
  end
  object frxBarCodeObject1: TfrxBarCodeObject
    Left = 328
    Top = 120
  end
  object frxReportTableObject1: TfrxReportTableObject
    Left = 480
    Top = 120
  end
  object frxCheckBoxObject1: TfrxCheckBoxObject
    Left = 624
    Top = 120
  end
  object frxCrossObject1: TfrxCrossObject
    Left = 736
    Top = 120
  end
  object frxChartObject1: TfrxChartObject
    Left = 840
    Top = 120
  end
  object frxHTML5DivExport1: TfrxHTML5DivExport
    UseFileCache = True
    ShowProgress = True
    OverwritePrompt = False
    DataOnly = False
    OpenAfterExport = False
    MultiPage = False
    Formatted = True
    PictureFormat = pfPNG
    UnifiedPictures = True
    Navigation = True
    EmbeddedPictures = True
    EmbeddedCSS = True
    Outline = False
    HTML5 = True
    AllPictures = False
    ExportAnchors = True
    PictureTag = 0
    Left = 640
    Top = 48
  end
  object frxRichObject1: TfrxRichObject
    Left = 584
    Top = 216
  end
  object frxPDFObject1: TfrxPDFObject
    Left = 712
    Top = 256
  end
  object frxIBXComponents1: TfrxIBXComponents
    DefaultDatabase = IBDatabase1
    Left = 440
    Top = 224
  end
  object IBDatabase1: TIBDatabase
    LoginPrompt = False
    ServerType = 'IBServer'
    Left = 32
    Top = 304
  end
  object frxOLEObject1: TfrxOLEObject
    Left = 208
    Top = 40
  end
  object VorlagenQuery: TIBQuery
    Database = IBDatabase1
    BufferChunks = 1000
    CachedUpdates = False
    ParamCheck = True
    SQL.Strings = (
      'Select Haupttext'
      'from '
      'Vorlagen where'
      'Bereich=:Bereich'
      'and'
      'art=:ART'
      'and'
      'name=:NAME'
      'and'
      'DokTyp='#39'F'#39)
    PrecommittedReads = False
    Left = 128
    Top = 304
    ParamData = <
      item
        DataType = ftWideString
        Name = 'BEREICH'
        ParamType = ptUnknown
      end
      item
        DataType = ftWideString
        Name = 'ART'
        ParamType = ptUnknown
      end
      item
        DataType = ftWideString
        Name = 'NAME'
        ParamType = ptUnknown
      end>
  end
end
