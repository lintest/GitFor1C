&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	RemoteURL = "https://github.com/lintest/GitFor1C";
EndProcedure

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
	EndIf;
	
EndProcedure

&AtClient
Procedure RepoClone(Command)
	
	If CheckFilling() Then
		NotifyDescription = New NotifyDescription("EndCloneRepo", ThisForm);
		FormOwner.git.BeginCallingClone(NotifyDescription, RemoteURL, LocalPath);
	EndIf;
	
EndProcedure

&AtClient
Procedure EndCloneRepo(ResultCall, ParametersCall, AdditionalParameters) Export
	
	JsonData = FormOwner.JsonLoad(ResultCall);
	If JsonData.success Then
		FileArray = New Array;
		FileArray.Add(LocalPath);
		FormOwner.OpenFolderEnd(FileArray, Undefined);
		Close(True);
	Else
		ShowMessageBox( , JsonData.Error.Message, 10);
	EndIf;
	
EndProcedure