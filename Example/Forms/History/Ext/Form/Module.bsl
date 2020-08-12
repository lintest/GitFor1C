&AtClient
Procedure OnOpen(Cancel)

	History.Clear();
	NotifyDescription = New NotifyDescription("EndCallingHistory", ThisForm);
	FormOwner.git.BeginCallingHistory(NotifyDescription);
	
EndProcedure

&AtClient
Procedure EndCallingHistory(ResultCall, ParametersCall, AdditionalParameters) Export
	
	History.Clear();
	JsonData = FormOwner.JsonLoad(ResultCall);
	if JsonData.Success Then 
		For Each Item In JsonData.result Do
			Row = History.Add();
			FillPropertyValues(Row, Item);
			Row.Date = ToLocalTime('19700101' + Item.time);
		EndDo;
	EndIf
	
EndProcedure

&AtClient
Procedure HistoryOnActivateRow(Item)
	
	AttachIdleHandler("BeginLoadTree", 0.1, True);
	
EndProcedure

&AtClient
Procedure BeginLoadTree() Export
	
	Tree.GetItems().Clear();
	Data = Items.History.CurrentData;
	If Data <> Undefined Then
		NotifyDescription = New NotifyDescription("EndLoadTree", ThisForm);
		FormOwner.git.BeginCallingTree(NotifyDescription, Data.Id);
	EndIf;
	
EndProcedure

&AtClient
Procedure EndLoadTree(ResultCall, ParametersCall, AdditionalParameters) Export
	
	Tree.GetItems().Clear();
	JsonData = FormOwner.JsonLoad(ResultCall);
	if JsonData.Success Then 
		For Each Item In JsonData.result Do
			Names = StrSplit(Item.Root + Item.Name, "/", False);
			CurrentItems = Tree.GetItems();
			While Names.Count() > 0 Do
				CurrentName = Names[0];
				CurrentRow = Undefined;
				For Each ChildItem In CurrentItems Do
					If ChildItem.Name = CurrentName Then
						CurrentRow = ChildItem;
						Break;
					EndIf;
				EndDo;
				If CurrentRow = Undefined Then
					CurrentRow = CurrentItems.Add();
					CurrentRow.Name = CurrentName;
				EndIf;
				CurrentItems = CurrentRow.GetItems();
				Names.Delete(0);
			EndDo;
		EndDo;
	EndIf;
	
EndProcedure