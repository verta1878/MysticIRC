UNIT dfsProgressBar;

INTERFACE

Uses
        Classes, ComCtrls, Graphics;

Type
        TdfsProgressBar= class(TProgressBar)

                  Private
                        FColor: TColor;
                Protected
                        Procedure SetColor (Value: TColor);
                Public
                        Constructor Create (AOwner: TComponent); override;
                Published
                        Property Color: TColor
                                Read FColor Write SetColor;
        end; // TdfsProgressbar

Procedure Register;

IMPLEMENTATION

Uses
        Windows;

Constructor TdfsProgressBar.Create (AOwner: TComponent);
Begin
        Inherited Create (AOwner);

        FColor:= clActiveCaption;
End; // TdfsProgressBar.Create

Procedure TdfsProgressBar.SetColor (Value: TColor);
Begin
        If FColor <> Value then
                begin
                        FColor:= Value;
                        PostMessage(Self.Handle, $0409, 0, Value);
                end;
End; // TdfsProgressBar.SetColor

Procedure Register;
Begin
        RegisterComponents('DFS', [TdfsProgressBar]);
End; // Register

END.




