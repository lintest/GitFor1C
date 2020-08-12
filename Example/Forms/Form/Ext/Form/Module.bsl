&AtClient
Var AddInId, git Export;

#Region FormEvents

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	LoadEditor();
	If Parameters.Property("AddInURL", AddInURL) Then
		File = New File(AddInURL);
		If Not File.Exist() Then
			SetAddInURL();
		EndIf;
	Else
		SetAddInURL();
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	Items.MainPages.CurrentPage = Items.FolderPage;
	AddInId = "_" + StrReplace(New UUID, "-", "");
	DoAttachingAddIn(True);
	
EndProcedure

&AtClient
Procedure EditorDocumentComplete(Item)
	
	view = Items.Editor.Document.defaultView;
	VanessaGherkinProvider = view.VanessaGherkinProvider;
	VanessaGherkinProvider.setKeywords(GetKeywords());
	view.createVanessaDiffEditor("", "", "text");
	view.createVanessaEditor("", "text").setVisible(False);
	
EndProcedure

#EndRegion

#Region FormActions

&AtClient
Procedure AutoTest(Command)
	
	NewName = GetFormName("Test");
	NewParams = New Structure("AddInId", AddInId);
	TestForm = GetForm(NewName, NewParams, ThisForm, New Uuid);
	TestForm.Test(AddInId);
	
EndProcedure

&AtClient
Procedure OpenFolder(Command)
	
	NotifyDescription = New NotifyDescription("OpenFolderEnd", ThisForm);
	FileDialog = New FileDialog(FileDialogMode.ChooseDirectory);
	FileDialog.Show(NotifyDescription);
	
EndProcedure

&AtClient
Procedure CloseFolder(Command)
	
	git.BeginCallingClose(New NotifyDescription);
	SetCurrentPage(Items.FolderPage);
	Repository = Undefined;
	Directory = Undefined;
	Title = Undefined;
	
EndProcedure

&AtClient
Procedure CloneRepository(Command)
	
	OpenForm(GetFormName("Clone"), , ThisForm, New Uuid);
	
EndProcedure

&AtClient
Procedure InitRepository(Command)
	
	NotifyDescription = New NotifyDescription("OpenRepositoryEnd", ThisForm);
	git.BeginCallingInit(NotifyDescription, Directory);
	
EndProcedure

&AtClient
Procedure ViewSettings(Command)
	
	OpenForm(GetFormName("Settings"), , ThisForm, New Uuid);
	
EndProcedure

&AtClient
Procedure ViewHistory(Command)

	OpenForm(GetFormName("History"), , ThisForm, New Uuid);
	
EndProcedure

&AtClient
Procedure ShowExplorer(Command)
	
	If Not IsBlankString(Directory) Then
		SetCurrentPage(Items.ExplorerPage);
		FillExplorerItems(Explorer.GetItems(), Directory);
		CurrentItem = Items.Explorer;
	EndIf;
	
EndProcedure

&AtClient
Procedure ShowSearch(Command)
	
	If Not IsBlankString(Directory) Then
		SetCurrentPage(Items.SearchPage);
		CurrentItem = Items.SearchText;
	EndIf;
	
EndProcedure

&AtClient
Procedure ShowControl(Command)
	
	If Not IsBlankString(Directory) Then
		SetCurrentPage(Items.StatusPage);
		BeginCallingStatus();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHandlers

&AtClient
Procedure OpenFolderEnd(SelectedFiles, AdditionalParameters) Export
	
	If SelectedFiles <> Undefined Then
		VanessaEditor().setVisible(False);
		EditableFilename = Undefined;
		File = New File(SelectedFiles[0]);
		Title = File.Name;
		AutoTitle = True;
		Directory = File.FullName;
		NotifyDescription = New NotifyDescription("FindFolderEnd", ThisForm, File.FullName);
		git.BeginCallingFind(NotifyDescription, SelectedFiles[0]);
	EndIf;
	
EndProcedure

&AtClient
Procedure FindFolderEnd(ResultCall, ParametersCall, AdditionalParameters) Export
	
	JsonData = JsonLoad(ResultCall);
	If JsonData.Success Then
		File = New File(JsonData.result);
		Repository = File.Path;
		NotifyDescription = New NotifyDescription("OpenRepositoryEnd", ThisForm);
		git.BeginCallingOpen(NotifyDescription, JsonData.Result);
	Else
		SetCurrentPage(Items.InitPage);
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenRepositoryEnd(ResultCall, ParametersCall, AdditionalParameters) Export
	
	JsonData = JsonLoad(ResultCall);
	If JsonData.Success Then
		BeginCallingStatus();
	EndIf;
	
EndProcedure

&AtClient
Procedure EndOpenFile(ResultCall, ParametersCall, AdditionalParameters) Export
	
	BinaryData = ParametersCall[0];
	Encoding = ParametersCall[1];
	FileName = AdditionalParameters;
	
	If ResultCall = True Then
		VanessaEditor().setValue("binary", "");
		VanessaEditor().setReadOnly(True);
	Else
		TextReader = New TextReader;
		TextReader.Open(BinaryData.OpenStreamForRead(), TextEncoding.UTF8);
		VanessaEditor().setValue(TextReader.Read(), FileName);
		VanessaEditor().setReadOnly(False);
		EditableFilename = FileName;
		EditableEncoding = Encoding;
	EndIf;
	VanessaEditor().setVisible(True);
	
EndProcedure

#EndRegion

#Region ServerTools

&AtServer
Procedure SetAddInURL()
	
	AddInTemplate = FormAttributeToValue("Object").GetTemplate("GitFor1C");
	AddInURL = PutToTempStorage(AddInTemplate, UUID);
	
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

#EndRegion

#Region ClientTools

&AtClient
Function VanessaEditor()
	
	Return Items.Editor.Document.defaultView.VanessaEditor;
	
EndFunction

&AtClient
Function VADiffEditor()
	
	Return Items.Editor.Document.defaultView.VADiffEditor;
	
EndFunction

&AtClient
Function GetKeywords()
	
	WordsRu = "
		|и
		|когда
		|тогда
		|затем
		|дано
		|функция
		|функционал
		|функциональность
		|свойство
		|предыстория
		|контекст
		|сценарий
		|структура сценария
		|к тому же
		|примеры
		|допустим
		|пусть
		|если
		|иначеесли
		|иначе
		|то
		|также
		|но
		|а
		|";
	
	WordsEn = "
		|feature
		|functionality
		|business need
		|ability
		|background
		|scenario outline
		|scenario
		|examples
		|given
		|when
		|then
		|and
		|but
		|if
		|elseif
		|else
		|";
	
	split = "
		|";
	
	WordList = StrSplit(WordsRu + WordsEn, split, False);
	Return JsonDump(WordList);
	
EndFunction

&AtClient
Function JsonLoad(Json) Export
	
	JSONReader = New JSONReader;
	JSONReader.SetString(Json);
	Value = ReadJSON(JSONReader);
	JSONReader.Close();
	Return Value;
	
EndFunction

&AtClient
Function JsonDump(Value) Export
	
	JSONWriter = New JSONWriter;
	JSONWriter.SetString();
	WriteJSON(JSONWriter, Value);
	Return JSONWriter.Close();
	
EndFunction

&AtClient
Function GetFormName(Name)
	
	Names = StrSplit(FormName, ".");
	Names[Names.Count() - 1] = Name;
	Return StrConcat(Names, ".");
	
EndFunction

&AtClient
Procedure SetCurrentPage(Page)
	
	ClearAllItems();
	VanessaEditor().setVisible(False);
	EditableFilename = Undefined;
	Items.FormShowControl.Check = (Page = Items.StatusPage OR Page = Items.InitPage);
	Items.FormShowExplorer.Check = (Page = Items.ExplorerPage);
	Items.FormShowSearch.Check = (Page = Items.SearchPage);
	Items.MainPages.CurrentPage = Page;
	
EndProcedure

&AtClient
Procedure ClearAllItems()
	
	Files.GetItems().Clear();
	Status.GetItems().Clear();
	Explorer.GetItems().Clear();
	VanessaEditor().setVisible(False);
	EditableFilename = Undefined;
	
EndProcedure

&AtClient
Function BeginOpenFile(FileName)
	
	BinaryData = New BinaryData(FileName);
	NotifyDescription = New NotifyDescription("EndOpenFile", ThisForm, FileName);
	git.BeginCallingIsBinary(NotifyDescription, BinaryData);
	
EndFunction

#EndRegion

#Region AttachAddIn

&AtClient
Procedure DoAttachingAddIn(AdditionalParameters) Export
	
	NotifyDescription = New NotifyDescription("AfterAttachingAddIn", ThisForm, AdditionalParameters);
	BeginAttachingAddIn(NotifyDescription, AddInURL, AddInId, AddInType.Native);
	
EndProcedure

&AtClient
Procedure AfterAttachingAddIn(Connected, AdditionalParameters) Export
	
	If Connected Then
		git = New("AddIn." + AddInId + ".GitFor1C");
		NotifyDescription = New NotifyDescription("AfterGettingVersion", ThisForm);
		git.BeginGettingVersion(NotifyDescription);
	ElsIf AdditionalParameters = True Then
		NotifyDescription = New NotifyDescription("DoAttachingAddIn", ThisForm, False);
		BeginInstallAddIn(NotifyDescription, AddInURL);
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterGettingVersion(Value, AdditionalParameters) Экспорт
	
	Title = "GIT for 1C, version " + Value;
	AutoTitle = False;
	
EndProcedure

#EndRegion

#Region FileExplorer

#Region FileExplorer_Events

&AtClient
Procedure ExplorerOnActivateRow(Item)
	
	AttachIdleHandler("ExplorerReadFile", 0.1, True);
	
EndProcedure

&AtClient
Procedure ExplorerBeforeExpand(Item, Row, Cancel)
	
	ParentRow = Explorer.FindByID(Row);
	If ParentRow <> Undefined Then
		FillExplorerItems(ParentRow.GetItems(), ParentRow.Fullname, ParentRow);
	EndIf;
	
EndProcedure

#EndRegion

#Region FileExplorer_Handlers

&AtClient
Procedure EndFindingFiles(FilesFound, AdditionalParameters) Export
	
	ParentNode = AdditionalParameters.Parent;
	ParentItems = AdditionalParameters.Items;
	
	ParentItems.Clear();
	OnlyFiles = New Array;
	For Each File In FilesFound Do
		If (File.IsDirectory()) Then
			If File.Name = ".git" Then
				Continue;
			EndIf;
			Row = ParentItems.Add();
			Row.IsDirectory = True;
			FillPropertyValues(Row, File);
			Row.GetItems().Add();
		Else
			OnlyFiles.Add(File);
		EndIf;
	EndDo;
	
	For Each File In OnlyFiles Do
		FillPropertyValues(ParentItems.Add(), File);
	EndDo;
	
	If ParentNode <> Undefined Then
		If ParentItems.Count() = 0 Then
			Items.Explorer.Collapse(ParentNode.GetId());
			ParentItems.Add();
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure ExplorerReadFile() Export
	
	Data = Items.Explorer.CurrentData;
	If Data <> Undefined Then
		If Data.IsDirectory Then
			VanessaEditor().setVisible(False);
			EditableFilename = Undefined;
		Else
			BeginOpenFile(Data.fullname);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region FileExplorer_Tools

&AtClient
Procedure FillExplorerItems(Items, Directory, Parent = Undefined)
	
	AdditionalParameters = New Structure("Items, Parent", Items, Parent);
	NotifyDescription = New NotifyDescription("EndFindingFiles", ThisForm, AdditionalParameters);
	BeginFindingFiles(NotifyDescription, Directory, "*.*", False);
	
EndProcedure

#EndRegion

#EndRegion

#Region FileSearching

#Region FileSearching_Events

&AtClient
Procedure SearchTextOnChange(Item)
	
	BeginSearchText();
	
EndProcedure

&AtClient
Procedure SearchFiles(Command)

	BeginSearchText();
	
EndProcedure

&AtClient
Procedure FilesOnActivateRow(Item)
	
	AttachIdleHandler("SearchReadFile", 0.1, True);
	
EndProcedure

#EndRegion

#Region FileSearching_Handlers

&AtClient
Procedure EndSearchText(ResultCall, ParametersCall, AdditionalParameters) Export
	
	Files.GetItems().Clear();
	JsonData = JsonLoad(ResultCall);
	If TypeOf(JsonData) = Type("Array") Then
		For Each Item In JsonData Do
			Row = Files.GetItems().Add();
			FillPropertyValues(Row, Item);
		EndDo;
	EndIf;
	
EndProcedure

#EndRegion

#Region FileSearching_Tools

&AtClient
Procedure BeginSearchText()
	
	Files.GetItems().Clear();
	If Not IsBlankString(SearchText) Then
		NotifyDescription = New NotifyDescription("EndSearchText", ThisForm);
		git.BeginCallingFindFiles(NotifyDescription, Directory, "*.*", SearchText, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure SearchReadFile() Export
	
	Data = Items.Files.CurrentData;
	If Data <> Undefined Then
		BeginOpenFile(Data.path);
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion

#Region SourceControl

#Region SourceControl_Actions

&AtClient
Procedure IndexRefresh(Command)
	
	BeginCallingStatus();
	
EndProcedure

&AtClient
Procedure IndexAdd(Command)
	
	AppendArray = New Array;
	RemoveArray = New Array;
	For Each Id In Items.Status.SelectedRows Do
		Row = Status.FindByID(Id);
		If Not IsBlankString(Row.new_name) Then
			If Row.status = "DELETED" Then
				RemoveArray.Add(Row.new_name);
			Else
				AppendArray.Add(Row.new_name);
			EndIf;
		EndIf;
	EndDo;
	
	git.BeginCallingAdd(GetIndexNotify(), JsonDump(AppendArray), JsonDump(RemoveArray));
	
EndProcedure

&AtClient
Procedure IndexReset(Command)
	
	git.BeginCallingReset(GetIndexNotify(), SelectedStatusJson());
	
EndProcedure

&AtClient
Procedure IndexDiscard(Command)
	
	NotifyDescription = New NotifyDescription("BeforeCallingDiscard", ThisForm);
	MessageText = "Are you sure you want to discard changes?";
	ShowQueryBox(NotifyDescription, MessageText, QuestionDialogMode.OKCancel, 10);
	
EndProcedure

&AtClient
Procedure IndexOpen(Command)
	
	Row = Items.Status.CurrentData;
	If Row = Undefined Then
		Return;
	ElsIf Row.Status = "DELETED" Then
		NotifyDescription = New NotifyDescription("EndIndexOpen", ThisForm, Row.old_name);
		git.BeginCallingBlob(NotifyDescription, Row.old_id);
	ElsIf Not IsBlankString(Row.new_id) Then
		NotifyDescription = New NotifyDescription("EndIndexOpen", ThisForm, Row.new_name);
		git.BeginCallingBlob(NotifyDescription, Row.new_id);
	Else
		BeginOpenFile(Repository + Row.new_name);
	EndIf;
	
EndProcedure

&AtClient
Procedure RepoCommit(Command)
	
	If IsBlankString(Message) Then
		UserMessage = New UserMessage;
		UserMessage.Text = "Fill the field ""Message""";
		UserMessage.DataPath = "Message";
		UserMessage.Message();
	Else
		NotifyDescription = New NotifyDescription("BeforeCallingCommit", ThisForm);
		git.BeginCallingStatus(NotifyDescription);
	EndIf;
	
EndProcedure

#EndRegion

#Region SourceControl_Events

&AtClient
Procedure StatusOnActivateRow(Item)
	
	Row = Items.Status.CurrentData;
	If Row = Undefined Then
		Return;
	EndIf;
	
	If IsBlankString(Row.status) Then
		VanessaEditor().setVisible(False);
		EditableFilename = Undefined;
		Return;
	EndIf;
	
	If Row.Status = "DELETED" Then
		VanessaEditor = VanessaEditor();
		VanessaEditor.setValue(OldFileText(Row), Row.old_name);
		VanessaEditor.setVisible(True);
		VanessaEditor.setReadOnly(True);
	Else
		NewText = NewFileText(Row);
		DiffEditor = VADiffEditor();
		DiffEditor.setValue(OldFileText(Row), Row.old_name, NewText, Row.new_name);
		DiffEditor.setReadOnly(Not IsBlankString(Row.new_id) OR NewText = "binary");
		DiffEditor.setVisible(True);
	EndIf;
	
EndProcedure

#EndRegion

#Region SourceControl_Handlers

&AtClient
Procedure BeforeCallingDiscard(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.OK Then
		git.BeginCallingDiscard(GetIndexNotify(), SelectedStatusJson());
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeCallingCommit(ResultCall, ParametersCall, AdditionalParameters) Export
	
	Var Array;
	
	JsonData = JsonLoad(ResultCall);
	If JsonData.success Then
		If TypeOf(JsonData.result) = Type("Structure") Then
			If JsonData.result.Property("Index", Array) And TypeOf(Array) = Type("Array") Then
				For Each Item In Array Do
					NotifyDescription = New NotifyDescription("EndCallingCommit", ThisForm);
					git.BeginCallingCommit(NotifyDescription, Message);
					Return;
				EndDo;
			EndIf;
		EndIf;
	EndIf;
	
	MessageText = "There are no staged changes to commit.";
	ShowMessageBox(New NotifyDescription, MessageText, 10, );
	
EndProcedure

&AtClient
Procedure EndCallingCommit(ResultCall, ParametersCall, AdditionalParameters) Export
	
	JsonData = JsonLoad(ResultCall);
	If JsonData.success Then
		ClearAllItems();
		Message = Undefined;
		BeginCallingStatus();
	ElsIf JsonData.error.code = 0 Then
		SetCurrentPage(Items.InitPage);
	Else
		UserMessage = New UserMessage;
		UserMessage.Text = JsonData.error.Message;
		UserMessage.Message();
	EndIf;
	
EndProcedure

&AtClient
Procedure EndCallingStatus(ResultCall, ParametersCall, AdditionalParameters) Export
	
	JsonData = JsonLoad(ResultCall);
	If JsonData.success Then
		SetCurrentPage(Items.StatusPage);
		CurrentItem = Items.Status;
		If TypeOf(JsonData.result) = Type("Structure") Then
			AddStatusItems(JsonData.result, "Index", "Staged Changes");
			AddStatusItems(JsonData.result, "Work", "Changes");
		EndIf;
	ElsIf JsonData.error.code = 0 Then
		SetCurrentPage(Items.InitPage);
		Repository = Undefined;
	EndIf;
	
EndProcedure

&AtClient
Procedure EndCallingIndex(ResultCall, ParametersCall, AdditionalParameters) Export
	
	BeginCallingStatus();
	
EndProcedure

&AtClient
Procedure EndIndexOpen(ResultCall, ParametersCall, AdditionalParameters) Export
	
	BinaryData = ResultCall;
	Encoding = ParametersCall[1];
	FileName = AdditionalParameters;
	
	If Encoding < 0 Then
		VanessaEditor().setValue("binary", "");
	Else
		TextReader = New TextReader;
		TextReader.Open(BinaryData.OpenStreamForRead(), TextEncoding.UTF8);
		VanessaEditor().setValue(TextReader.Read(), FileName);
	EndIf;
	VanessaEditor().setReadOnly(True);
	VanessaEditor().setVisible(True);
	
EndProcedure

#EndRegion

#Region SourceControl_Tools

&AtClient
Function BeginCallingStatus()
	
	NotifyDescription = New NotifyDescription("EndCallingStatus", ThisForm);
	git.BeginCallingStatus(NotifyDescription);
	
EndFunction

&AtClient
Procedure AddStatusItems(JsonData, Key, Name)
	
	Var Array;
	
	If JsonData.Property(Key, Array) Then
		ParentRow = Status.GetItems().Add();
		ParentRow.Name = Name;
		For Each Item In Array Do
			If Item.Status = "IGNORED" Then
				Continue;
			EndIf;
			Row = ParentRow.GetItems().Add();
			FillPropertyValues(Row, Item);
			Row.name = Item.new_name;
			Row.size = Item.new_size;
		EndDo;
		Items.Status.Expand(ParentRow.GetID());
		If ParentRow.GetItems().Count() = 0 Then
			Status.GetItems().Delete(ParentRow);
		EndIf
	EndIf
	
EndProcedure

&AtClient
Function SelectedStatusJson()
	
	FileArray = New Array;
	For Each Id In Items.Status.SelectedRows Do
		Row = Status.FindByID(Id);
		If Not IsBlankString(Row.new_name) Then
			FileArray.Add(Row.new_name);
		EndIf;
	EndDo;
	Return JsonDump(FileArray);
	
EndFunction

&AtClient
Function GetIndexNotify()
	
	Return New NotifyDescription("EndCallingIndex", ThisForm);
	
EndFunction

&AtClient
Function ReadIndexBlob(id)
	
	If IsBlankString(id) Then
		Return "";
	Else
		Encoding = Undefined;
		BinaryData = git.blob(id, Encoding);
		If Encoding < 0 Then
			Return "binary";
		Else
			If TypeOf(BinaryData) = Type("BinaryData") Then
				TextReader = New TextReader;
				TextReader.Open(BinaryData.OpenStreamForRead(), TextEncoding.UTF8);
				Return TextReader.Read();
			Else
				Return "";
			EndIf;
		EndIf;
	EndIf;
	
EndFunction

&AtClient
Function NewFileText(Row)
	
	If IsBlankString(Row.new_id) Then
		id = git.file(Row.new_name);
	Else
		id = Row.new_id;
	EndIf;
	
	Return ReadIndexBlob(id);
	
	
EndFunction

&AtClient
Function OldFileText(Row)
	
	If IsBlankString(Row.old_id) Then
		Return "";
	Else
		Return ReadIndexBlob(Row.old_id);
	EndIf;
	
EndFunction

#EndRegion

#EndRegion
