&AtClient
Var AddInId, git;

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	AddInTemplate = FormAttributeToValue("Object").GetTemplate("GitFor1C");
	AddInURL = PutToTempStorage(AddInTemplate, UUID);
	AddInURL = "C:\Cpp\GitFor1C\bind64\libGitFor1CWin64.dll";
	RemoteURL = "https://github.com/lintest/GitFor1C";
	LocalPath = "C:\Cpp\TestRepo\";
	Message = "Init commit";
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)

	AddInId = "_" + StrReplace(New  UUID, "-", "");
	DoAttachingAddIn(True);
	
EndProcedure

&AtClient
Procedure DoAttachingAddIn(AdditionalParameters) Export
	
	NotifyDescription = New NotifyDescription("AfterAttachingAddIn", ThisForm, AdditionalParameters);
	BeginAttachingAddIn(NotifyDescription, AddInURL, AddInId, AddInType.Native); 
	
EndProcedure

&AtClient
Procedure AfterAttachingAddIn(Подключение, ДополнительныеПараметры) Экспорт
	
	Если Подключение Тогда
		git = Новый("AddIn." + AddInId + ".GitFor1C");
		NotifyDescription = New NotifyDescription("AfterGettingVersion", ThisForm);
		git.BeginGettingVersion(NotifyDescription);
	ИначеЕсли ДополнительныеПараметры = Истина Тогда
		NotifyDescription = New NotifyDescription("DoAttachingAddIn", ЭтотОбъект, Ложь);
		BeginInstallAddIn(NotifyDescription, AddInURL);
	КонецЕсли;
	
EndProcedure

&AtClient
Процедура AfterGettingVersion(Значение, ДополнительныеПараметры) Экспорт
	
	Заголовок = "GIT для 1C, версия " + Значение;
	
КонецПроцедуры	

&AtClient
Функция ПрочитатьСтрокуJSON(ТекстJSON)
	
	Если ПустаяСтрока(ТекстJSON) Тогда
		Возврат Неопределено;
	КонецЕсли;
	
	ЧтениеJSON = Новый ЧтениеJSON();
	ЧтениеJSON.УстановитьСтроку(ТекстJSON);
	Возврат ПрочитатьJSON(ЧтениеJSON);
	
КонецФункции

&AtClient
Procedure PathStartChoice(Item, ChoiceData, StandardProcessing)

	NotifyDescription = New NotifyDescription("PathEndChoice", ThisForm);
	FileDialog = New FileDialog(FileDialogMode.ChooseDirectory);
	FileDialog.Show(NotifyDescription);
	
EndProcedure

&AtClient
Procedure PathEndChoice(SelectedFiles, AdditionalParameters) Экспорт
	
	If SelectedFiles <> Undefined Then
		LocalPath = SelectedFiles[0];
	EndIf
	
EndProcedure

&AtClient
Procedure EndCallingGit(ResultCall, ParametersCall, AdditionalParameters) Export
	
	If Not IsBlankString(ResultCall) Then
		Message(ResultCall);
	EndIf
	
EndProcedure

&AtClient
Function GitNotifyDescription()
	
	return New NotifyDescription("EndCallingGit", ThisForm);
	
EndFunction

&AtClient
Procedure RepoInit(Command)
	
	git.BeginCallingInit(GitNotifyDescription(), LocalPath);
	
EndProcedure

&AtClient
Procedure RepoClone(Команда)
	
	NotifyDescription = New NotifyDescription("EndCallingGit", ThisForm);
	git.BeginCallingСlone(GitNotifyDescription(), RemoteURL, LocalPath);
	
EndProcedure

&AtClient
Procedure RepoFind(Command)

	git.BeginCallingFind(GitNotifyDescription(), LocalPath);
	
EndProcedure

&AtClient
Procedure RepoOpen(Command)

	git.BeginCallingOpen(GitNotifyDescription(), LocalPath);
	
EndProcedure

&AtClient
Procedure RepoStatus(Command)
	
	git.BeginCallingStatus(GitNotifyDescription());
	
EndProcedure

&AtClient
Procedure RepoCommit(Command)
	git.BeginCallingCommit(GitNotifyDescription(), Message);
EndProcedure
