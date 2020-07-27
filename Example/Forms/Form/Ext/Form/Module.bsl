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

#Region Json

&AtClient
Function JsonLoad(Json)

	JSONReader = New JSONReader;
	JSONReader.SetString(Json);
	Value = ReadJSON(JSONReader);
	JSONReader.Close();
	Return Value;

EndFunction

&AtClient
Function JsonDump(Value)

	JSONWriter = New JSONWriter;
	JSONWriter.SetString();
	WriteJSON(JSONWriter, Value);
	Return JSONWriter.Close();

EndFunction

#EndRegion

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
Procedure PathEndChoice(SelectedFiles, AdditionalParameters) Export
	
	If SelectedFiles <> Undefined Then
		LocalPath = SelectedFiles[0];
	EndIf
	
EndProcedure

&AtClient
Procedure EndCallingMessage(ResultCall, ParametersCall, AdditionalParameters) Export
	
	If Not IsBlankString(ResultCall) Then
		Message(ResultCall);
	EndIf
	
EndProcedure

&AtClient
Function GitMessageNotify()
	
	return New NotifyDescription("EndCallingMessage", ThisForm);
	
EndFunction

&AtClient
Function GitStatusNotify()
	
	return New NotifyDescription("EndCallingStatus", ThisForm);
	
EndFunction

&AtClient
Procedure RepoInit(Command)
	
	git.BeginCallingInit(GitMessageNotify(), LocalPath);
	
EndProcedure

&AtClient
Procedure RepoClone(Команда)
	
	NotifyDescription = New NotifyDescription("EndCallingGit", ThisForm);
	git.BeginCallingСlone(GitMessageNotify(), RemoteURL, LocalPath);
	
EndProcedure

&AtClient
Procedure RepoFind(Command)

	git.BeginCallingFind(GitMessageNotify(), LocalPath);
	
EndProcedure

&AtClient
Procedure RepoOpen(Command)

	git.BeginCallingOpen(GitMessageNotify(), LocalPath);
	
EndProcedure

&AtClient
Procedure RepoStatus(Command)
	
	git.BeginCallingStatus(GitStatusNotify());
	
EndProcedure

&AtClient
Procedure EndCallingStatus(ResultCall, ParametersCall, AdditionalParameters) Export
	
	Files.Clear();
	For each Item in JsonLoad(ResultCall).result Do
		line = Files.Add();
		line.filepath = Item.filepath;
		line.statuses = "";
		For each Status in Item.statuses Do
			If Not IsBlankString(line.statuses) Then 
				line.statuses = line.statuses + ", ";
			EndIf;
			line.statuses = line.statuses + Status;
		EndDo;
	EndDo;
	
EndProcedure

&AtClient
Procedure RepoCommit(Command)
	git.BeginCallingCommit(GitMessageNotify(), Message);
EndProcedure

&AtClient
Procedure RepoInfo(Command)
	
	git.BeginCallingInfo(GitMessageNotify(), "HEAD^{commit}");
	
EndProcedure

&AtClient
Procedure AutoTest(Command)
	
	LocalPath = "C:\Cpp\TestRepo";
	DeleteFiles(LocalPath);
	CreateDirectory(LocalPath);
	git.init(LocalPath);
	
	FileText = 
	"First line
	|Second line
	|Third line
	|";
	
	For i = 1 To 9 Do
		FileName = Format(i, "ND=2;NG=") + ".txt";
		FilePath = LocalPath + "\" + FileName;
		TextWriter = New TextWriter;
		TextWriter.Open(FilePath, TextEncoding.UTF8);
		TextWriter.Write(FileText);
		TextWriter.Close();
		If i <= 7 Then git.add(FileName); EndIf;
		If i = 6 Then git.remove(FileName); EndIf;
		If i = 7 Then DeleteFiles(FilePath); EndIf;
		if i < 3 Then 
			TextWriter = New TextWriter;
			TextWriter.Open(FilePath, TextEncoding.UTF8);
			TextWriter.Write("Second line");
			TextWriter.Close();
		EndIf;
	EndDo;
	git.BeginCallingStatus(GitStatusNotify());
	
EndProcedure

&AtClient
Procedure IndexAdd(Command)
	
	For Each Id In Items.files.SelectedRows Do
		Row = Files.FindByID(Id);
		git.add(Row.filepath);
	EndDo;
	git.BeginCallingStatus(GitStatusNotify());
		
EndProcedure

&AtClient
Procedure IndexRemove(Command)

	For Each Id In Items.files.SelectedRows Do
		Row = Files.FindByID(Id);
		git.remove(Row.filepath);
	EndDo;
	git.BeginCallingStatus(GitStatusNotify());
	
EndProcedure

