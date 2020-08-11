&AtClient
Procedure GetDefaultSignature(Command)
	
	
	NotifyDescription = New NotifyDescription("EndDefaultSignature", ThisForm);
	FormOwner.git.BeginGettingSignature(NotifyDescription);
	
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
