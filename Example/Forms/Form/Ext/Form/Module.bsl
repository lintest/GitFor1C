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
	view.createVanessaDiffEditor();
	view.createVanessaEditor().setVisible(False);
	view.createVanessaTabs();
	
EndProcedure

#EndRegion

#Region FormActions

&AtClient
Procedure AutoTest(Command)
	
	NewName = GetFormName("Test");
	NewParams = New Structure("AddInURL", AddInURL);
	OpenForm(NewName, NewParams, ThisForm, New Uuid);
	
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
	
	NotifyDescription = New NotifyDescription("InitRepositoryEnd", ThisForm, Directory);
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
Procedure InitRepositoryEnd(ResultCall, ParametersCall, AdditionalParameters) Export
	
	JsonData = JsonLoad(ResultCall);
	If JsonData.Success Then
		NotifyDescription = New NotifyDescription("FindFolderEnd", ThisForm, AdditionalParameters);
		git.BeginCallingFind(NotifyDescription, AdditionalParameters);
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
	
	Var BinaryData, Encoding, FileName;
	
	BinaryData = ParametersCall[0];
	Encoding = ParametersCall[1];
	FileName = AdditionalParameters;
	
	If ResultCall = True Then
		SetEditorContent("binary", "", FileName, True);
	Else
		EditableEncoding = Encoding;
		TextReader = New TextReader(BinaryData.OpenStreamForRead(), TextEncoding.UTF8);
		SetEditorContent(TextReader.Read(), FileName, FileName, False);
	EndIf;
	
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
	
EndProcedure

&AtClient
Function BeginOpenFile(FileName)
	
	Try
		BinaryData = New BinaryData(FileName);
		NotifyDescription = New NotifyDescription("EndOpenFile", ThisForm, FileName);
		git.BeginCallingIsBinary(NotifyDescription, BinaryData);
	Except
		//Is director
	EndTry;
	
EndFunction

&AtClient
Procedure SetEditorContent(Content, FileName, Title, ReadOnly)
	
	File = New File(Title);
	VanessaTabs = Items.Editor.Document.defaultView.VanessaTabs;
	VanessaTabs.edit(Content, FileName, File.Name).setReadOnly(ReadOnly);
	
EndProcedure	

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
	For Each File In FilesFound Do
		If File.Name = ".git" Then
			Continue;
		EndIf;
		Row = ParentItems.Add();
		FillPropertyValues(Row, File);
		RowParams = New Structure("FileName, ParentItems", File.Name, ParentItems);
		NotifyDescription = New NotifyDescription("EndCheckingIsDirectory", ThisForm, RowParams);
		File.BeginCheckingIsDirectory(NotifyDescription);
	EndDo;
	
	If ParentNode <> Undefined Then
		If ParentItems.Count() = 0 Then
			Items.Explorer.Collapse(ParentNode.GetId());
			ParentItems.Add();
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Function CompareNames(Name1, Name2)
	
	CompareValues = New CompareValues;
	Return CompareValues.Compare(Name1, Name2);
	
EndFunction

&AtClient
Procedure EndCheckingIsDirectory(IsDirectory, AdditionalParameters) Export
	
	If (IsDirectory) Then
		FileName = AdditionalParameters.FileName;
		ParentItems = AdditionalParameters.ParentItems;
		For Each Row In ParentItems Do
			If Row.Name = FileName Then
				Row.IsDirectory = True;
				If Row.GetItems().Count() = 0 Then
					Row.GetItems().Add();
				EndIf;
				RowIndex = ParentItems.IndexOf(Row);
				While RowIndex > 0 Do
					PriorRow = ParentItems.Get(RowIndex - 1);
					If PriorRow.IsDirectory Then
						If CompareNames(PriorRow.Name, Row.Name) > 0 Then
							ParentItems.Move(RowIndex, -1);
						Else
							Break;
						EndIf;
					Else
						ParentItems.Move(RowIndex, -1);
					EndIf;
					RowIndex = ParentItems.IndexOf(Row);
				EndDo;
				Break;
			EndIf;
		EndDo;
	EndIf;
	
EndProcedure	

&AtClient
Procedure ExplorerReadFile() Export
	
	Data = Items.Explorer.CurrentData;
	If Data <> Undefined Then
		If Not Data.IsDirectory Then
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
		Return;
	EndIf;
	
	If Row.Status = "DELETED" Then
		If Not IsBlankString(Row.old_id) Then
			NotifyDescription = New NotifyDescription("EndReadingDeleted", ThisForm, Row.old_name);
			git.BeginCallingBlob(NotifyDescription, Row.old_id, 0);
		EndIf;
	Else
		RowData = New Structure("old_id,old_name,new_id,new_name");
		FillPropertyValues(RowData, Row);
		If IsBlankString(Row.new_id) Then
			Try
				BinaryData = New BinaryData(Repository + Row.new_name);
				RowData.Insert("BinaryData", BinaryData);
				NotifyDescription = New NotifyDescription("EndDiffFile", ThisForm, RowData);
				git.BeginCallingIsBinary(NotifyDescription, BinaryData);
			Except
				//Is director
			EndTry;
		Else
			NotifyDescription = New NotifyDescription("EndDiffBlob", ThisForm, RowData);
			BinaryData = git.BeginCallingBlob(NotifyDescription, RowData.new_id, 0);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region SourceControl_Handlers

&AtClient
Procedure EndDiffFile(ResultCall, ParametersCall, AdditionalParameters) Export
	
	RowData = AdditionalParameters;
	RowData.Insert("Encoding", ParametersCall[1]);
	RowData.Insert("ReadOnly", False);
	NotifyDescription = New NotifyDescription("EndReadingDiff", ThisForm, RowData);
	BinaryData = git.BeginCallingBlob(NotifyDescription, RowData.old_id, 0);
	
EndProcedure

&AtClient
Procedure EndDiffBlob(ResultCall, ParametersCall, AdditionalParameters) Export
	
	RowData = AdditionalParameters;
	RowData.Insert("BinaryData", ResultCall);
	RowData.Insert("Encoding", ParametersCall[1]);
	RowData.Insert("ReadOnly", True);
	NotifyDescription = New NotifyDescription("EndReadingDiff", ThisForm, RowData);
	BinaryData = git.BeginCallingBlob(NotifyDescription, RowData.old_id, 0);
	
EndProcedure

&AtClient
Procedure EndReadingDiff(ResultCall, ParametersCall, AdditionalParameters) Export
	
	Var BinaryData, Encoding, ReadOnly;
	
	BinaryData = ResultCall;
	Encoding = ParametersCall[1];
	RowData = AdditionalParameters;
	
	If Encoding < 0 Then
		old_text = "binary";
		old_name = "";
	Else
		If TypeOf(BinaryData) = Type("BinaryData") Then
			TextReader = New TextReader(BinaryData.OpenStreamForRead(), TextEncoding.UTF8);
			old_text = TextReader.Read();
			old_name = RowData.old_name;
		Else
			new_text = "error";
			old_name = "";
		EndIf;
	EndIf;
	
	If RowData.Encoding < 0 Then
		ReadOnly = true;
		new_text = "binary";
		new_name = "";
	Else
		If TypeOf(RowData.BinaryData) = Type("BinaryData") Then
			TextReader = New TextReader(RowData.BinaryData.OpenStreamForRead(), TextEncoding.UTF8);
			new_text = TextReader.Read();
			new_name = RowData.new_name;
			ReadOnly = RowData.ReadOnly;
		Else
			new_text = "error";
			new_name = "";
			ReadOnly = true;
		EndIf;
	EndIf;
	
	File = New File(new_name);
	VanessaTabs = Items.Editor.Document.defaultView.VanessaTabs;
	DiffEditor = VanessaTabs.diff(old_text, old_name, new_text, new_name, File.Name);
	DiffEditor.setReadOnly(ReadOnly);
	
EndProcedure

&AtClient
Procedure EndReadingDeleted(ResultCall, ParametersCall, AdditionalParameters) Export
	
	Var BinaryData, Encoding, FileName;
	
	BinaryData = ResultCall;
	Encoding = ParametersCall[1];
	FileName = AdditionalParameters;
	
	If Encoding < 0 Then
		SetEditorContent("binary", "", FileName, True);
	Else
		If TypeOf(BinaryData) = Type("BinaryData") Then
			TextReader = New TextReader(BinaryData.OpenStreamForRead(), TextEncoding.UTF8);
			SetEditorContent(TextReader.Read(), FileName, FileName, True);
		EndIf;
	EndIf;
	
EndProcedure

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
	
	Var BinaryData, Encoding, FileName;
	
	BinaryData = ResultCall;
	Encoding = ParametersCall[1];
	FileName = AdditionalParameters;
	
	If Encoding < 0 Then
		SetEditorContent("binary", "", FileName, True);
	Else
		TextReader = New TextReader(BinaryData.OpenStreamForRead(), TextEncoding.UTF8);
		SetEditorContent(TextReader.Read(), FileName, FileName, True);
	EndIf;
	
EndProcedure

#EndRegion

#Region SourceControl_Tools

&AtClient
Function BeginCallingStatus()
	
	NotifyDescription = New NotifyDescription("EndCallingStatus", ThisForm);
	git.BeginCallingStatus(NotifyDescription);
	
EndFunction

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

#EndRegion

#EndRegion
