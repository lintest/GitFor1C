&AtClient
Procedure OnOpen(Cancel)

	NotifyDescription = New NotifyDescription("EndRemoteList", ThisForm);
	FormOwner.git.BeginGettingRemoteList(NotifyDescription);
	
EndProcedure

&AtClient
Procedure GetDefaultSignature(Command)
	
	NotifyDescription = New NotifyDescription("EndDefaultSignature", ThisForm);
	FormOwner.git.BeginGettingSignature(NotifyDescription);
	
EndProcedure

&AtClient
Procedure EndRemoteList(Value, AdditionalParameters) Export 
	
	RemoteList.Clear();
	JsonData = FormOwner.JsonLoad(Value);
	If JsonData.success Then
		If TypeOf(JsonData.result) = Type("Array") Then 
			For Each RemoteItem In JsonData.result Do
				FillPropertyValues(RemoteList.Add(), RemoteItem);
			EndDo;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure EndDefaultSignature(Value, AdditionalParameters) Export 
	
	JsonData = FormOwner.JsonLoad(Value);
	If JsonData.success Then
		SignatureName = JsonData.result.name;
		SignatureEmail = JsonData.result.email;
	EndIf;
	
EndProcedure

&AtClient
Procedure SetSignatureAuthor(Command)
	
	FormOwner.git.BeginCallingSetAuthor(New NotifyDescription, SignatureName, SignatureEmail);
	
EndProcedure

&AtClient
Procedure SetSignatureCommitter(Command)

	FormOwner.git.BeginCallingSetCommitter(New NotifyDescription, SignatureName, SignatureEmail);

EndProcedure

