object DataModulBaseClass: TDataModulBaseClass
  OnCreate = DataModuleCreate
  OnDestroy = DataModuleDestroy
  Height = 480
  Width = 640
  object Query: TFDQuery
    Connection = Connection
    FetchOptions.AssignedValues = [evItems, evRowsetSize, evUnidirectional]
    FetchOptions.Unidirectional = True
    FetchOptions.RowsetSize = 1000
    FetchOptions.Items = []
    ResourceOptions.AssignedValues = [rvSilentMode]
    ResourceOptions.SilentMode = True
    UpdateOptions.AssignedValues = [uvEDelete, uvEInsert, uvEUpdate, uvCountUpdatedRecords, uvCheckRequired, uvCheckReadOnly, uvCheckUpdatable]
    UpdateOptions.EnableDelete = False
    UpdateOptions.EnableInsert = False
    UpdateOptions.EnableUpdate = False
    UpdateOptions.CountUpdatedRecords = False
    UpdateOptions.CheckRequired = False
    UpdateOptions.CheckReadOnly = False
    UpdateOptions.CheckUpdatable = False
    SQL.Strings = (
      'select * from adressen')
    Left = 208
    Top = 18
  end
  object Connection: TFDConnection
    Params.Strings = (
      'DriverID=IB'
      'Port=0'
      'Password=masterkey')
    FetchOptions.AssignedValues = [evRowsetSize]
    FetchOptions.RowsetSize = 100
    ResourceOptions.AssignedValues = [rvCmdExecTimeout, rvDirectExecute, rvAutoConnect, rvSilentMode, rvKeepConnection]
    ResourceOptions.DirectExecute = True
    ResourceOptions.SilentMode = True
    ResourceOptions.AutoConnect = False
    UpdateOptions.AssignedValues = [uvEDelete, uvEInsert, uvEUpdate, uvCountUpdatedRecords, uvCheckRequired, uvCheckReadOnly, uvCheckUpdatable]
    UpdateOptions.EnableDelete = False
    UpdateOptions.EnableInsert = False
    UpdateOptions.EnableUpdate = False
    UpdateOptions.CountUpdatedRecords = False
    UpdateOptions.CheckRequired = False
    UpdateOptions.CheckReadOnly = False
    UpdateOptions.CheckUpdatable = False
    LoginPrompt = False
    Left = 88
    Top = 186
  end
end
