&AtClient
Var AddInId, git;

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	LoadEditor();
	AddInTemplate = FormAttributeToValue("Object").GetTemplate("GitFor1C");
	AddInURL = PutToTempStorage(AddInTemplate, UUID);
	RemoteURL = "https://github.com/lintest/GitFor1C";
	LocalPath = "C:\Cpp\TestRepo\";
	Message = "Init commit";
	
EndProcedure

&AtServer
Procedure LoadEditor()

	TempFileName = GetTempFileName();
	DeleteFiles(TempFileName);
	CreateDirectory(TempFileName);

	BinaryData = FormAttributeToValue("Object").GetTemplate("VAEditor");
	ZipFileReader = New ZipFileReader(BinaryData.OpenStreamForRead());
	For each ZipFileEntry In ZipFileReader.Items Do
		ZipFileReader.Extract(ZipFileEntry, TempFileName, ZIPRestoreFilePathsMode.Restore);
		BinaryData = New BinaryData(TempFileName + "/" + ZipFileEntry.FullName);
		EditorURL = GetInfoBaseURL() + "/" + PutToTempStorage(BinaryData, UUID)
			+ "&localeCode=" + Left(CurrentSystemLanguage(), 2);
	EndDo;
	DeleteFiles(TempFileName);

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
	
	git.BeginCallingClone(GitMessageNotify(), RemoteURL, LocalPath);
	
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
	Items.FormPages.CurrentPage = Items.PageStatus;
	
EndProcedure

&AtClient
Procedure AddStatusItems(JsonData, Key)
	
	Var Array;

	If JsonData.Property(Key, Array) Then
		ParentRow = Status.GetItems().Add();
		ParentRow.Name = Key;
		For Each Item In Array Do
			Row = ParentRow.GetItems().Add();
			FillPropertyValues(Row, Item);
			Row.name = Item.new_name;
			Row.size = Item.new_size;
		EndDo;
		Items.Status.Expand(ParentRow.GetID());
	EndIf
	
EndProcedure	

&AtClient
Procedure SetStatus(TextJson) Export
	
	Status.GetItems().Clear();
	JsonData = JsonLoad(TextJson);
	If JsonData.success Then
		AddStatusItems(JsonData.result, "Index");
		AddStatusItems(JsonData.result, "Work");
	EndIf;
	
EndProcedure
	
&AtClient
Procedure EndCallingStatus(ResultCall, ParametersCall, AdditionalParameters) Export
	
	SetStatus(ResultCall);
	
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
Procedure RepoHistory(Command)
	
	History.Clear();
	TextJSON = git.history();
	For Each Item In JsonLoad(TextJSON).result Do
		Row = History.Add();
		FillPropertyValues(Row, Item);
		Row.Date = ToLocalTime('19700101' + Item.time);
	EndDo;
	Items.FormPages.CurrentPage = Items.PageHistory;
	
EndProcedure

&AtClient
Procedure WriteText(FilePath, FileText)
	TextWriter = New TextWriter;
	TextWriter.Open(FilePath, TextEncoding.UTF8);
	TextWriter.Write(FileText);
	TextWriter.Close();
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
		WriteText(FilePath, FileText);
		If i <= 7 Then git.add(FileName); EndIf;
		If i = 6 Then git.remove(FileName); EndIf;
		If i = 7 Then DeleteFiles(FilePath); EndIf;
		if i < 3 Then 
			WriteText(FilePath, "Second line");
		EndIf;
	EndDo;
	JsonText = git.status();
	SetStatus(JsonText);
	
EndProcedure

&AtClient
Procedure IndexAdd(Command)
	
	For Each Id In Items.Status.SelectedRows Do
		Row = Status.FindByID(Id);
		git.add(Row.name);
	EndDo;
	git.BeginCallingStatus(GitStatusNotify());
		
EndProcedure

&AtClient
Procedure IndexRemove(Command)

	For Each Id In Items.Status.SelectedRows Do
		Row = Status.FindByID(Id);
		git.remove(Row.name);
	EndDo;
	git.BeginCallingStatus(GitStatusNotify());
	
EndProcedure

&AtClient
Procedure GetDefaultSignature(Command)
	
	signature = JsonLoad(git.signature);
	Name = signature.result.name;
	Email = signature.result.email;
	
EndProcedure

&AtClient
Procedure SetSignatureAuthor(Command)

	git.setAuthor(Name, Email);
	
EndProcedure

&AtClient
Procedure SetSignatureCommitter(Command)

	git.setCommitter(Name, Email);
	
EndProcedure

&AtClient
Procedure RepoTree(Command)
	
	Tree.Clear();
	TextJSON = git.tree();
	For Each Item In JsonLoad(TextJSON).result Do
		Row = Tree.Add();
		FillPropertyValues(Row, Item);
	EndDo;
	Items.FormPages.CurrentPage = Items.PageTree;
	
EndProcedure

&AtClient
Procedure RepoDiff1(Command)
	RepoDiff("INDEX", "WORK")
EndProcedure

&AtClient
Procedure RepoDiff2(Command)
	RepoDiff("HEAD", "INDEX")
EndProcedure

&AtClient
Procedure RepoDiff3(Command)
	RepoDiff("HEAD", "WORK")
EndProcedure

&AtClient
Procedure RepoDiff(s1, s2)
	
	Diff.Clear();
	TextJSON = git.diff(s1, s2);
	result = JsonLoad(TextJSON).result;
	If TypeOf(result) = Type("Array") Then
		For Each Item In result Do
			Row = Diff.Add();
			FillPropertyValues(Row, Item);
		EndDo;
	EndIf;
	Items.FormPages.CurrentPage = Items.PageDiff;
	
EndProcedure

&AtClient
Procedure DiffSelection(Item, SelectedRow, Field, StandardProcessing)
	
	Row = Diff.FindByID(SelectedRow);
	If Row = Undefined Then
		Return;
	EndIf;
	BinaryData = git.blob(Row.new_id);
	TextDocument = New TextDocument;
	TextDocument.Read(BinaryData.OpenStreamForRead());
	TextDocument.Show();
		
EndProcedure

&AtClient
Procedure StatusOnActivateRow(Item)
	
	Row = Items.Status.CurrentData;
	if Row = Undefined Then 
		Return 
	EndIf;

	If IsBlankString(Row.old_id) Then
		OldText = "";
	Else
		BinaryData = git.blob(Row.old_id);
		TextReader = New TextReader;
		TextReader.Open(BinaryData.OpenStreamForRead());
		OldText = TextReader.Read();
	EndIf;
	
	If IsBlankString(Row.new_id) Then
		filepath = git.fullpath(Row.name);
		BinaryData = new BinaryData(filepath);
	Else
		BinaryData = git.blob(Row.new_id);
	EndIf;
	
	TextReader = New TextReader;
	TextReader.Open(BinaryData.OpenStreamForRead());
	NewText = TextReader.Read();
	
	old_name = String(New UUID) + "/" + Row.old_name;
	new_name = String(New UUID) + "/" + Row.new_name;
	Items.Editor.Document.defaultView.VanessaEditor.setValue(OldText, old_name, NewText, new_name);
	
EndProcedure

&AtClient
Procedure EditorDocumentComplete(Item)
	Items.Editor.Document.defaultView.createVanessaDiffEditor("", "", "text");
EndProcedure

