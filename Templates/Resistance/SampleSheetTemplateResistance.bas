Attribute VB_Name = "SampleSheetTemplateResistance"
Sub saveascsv()
Attribute saveascsv.VB_ProcData.VB_Invoke_Func = " \n14"
    Dim msnumber As String
    Dim save_path As String

    msnumber = Range("M8")
    
    #If Mac Then
        'save_path = "/Volumes/Research/Common/Equipment/MiSeq/MiSeqSampleSheets/" + msnumber + ".csv"
        'save_path = "/Users/schmutz.stefan/Desktop/" + msnumber + ".csv"
        MsgBox ("Speichere MiSeq SampleSheet manuell.")
        Exit Sub
    #Else
        save_path = "R:\Common\Equipment\MiSeq\MiSeqSampleSheets\" + msnumber + ".csv"
    #End If
    
    Application.ScreenUpdating = False
    Application.DisplayAlerts = False

    ThisWorkbook.Sheets("MiSeq SampleSheet").Copy
    ActiveWorkbook.SaveAs Filename:= _
        save_path, FileFormat:= _
        xlCSV, CreateBackup:=False
    ActiveWindow.Close

    Application.DisplayAlerts = True
    Application.ScreenUpdating = True
End Sub

Sub validate()

    Application.ScreenUpdating = False
    ThisWorkbook.Sheets("MiSeq SampleSheet").Activate
    ActiveSheet.Unprotect
    Dim exceptionCount As Integer
    exceptionCount = 0
    
    'Validate Operator Name
    Range("B3").Select
    
    If Selection.Validation.Value Then
        Selection.Interior.ColorIndex = 0
    Else
        exceptionCount = exceptionCount + 1
        Selection.Interior.ColorIndex = 6
    End If
    
    'Validate Sequencingdate
    Range("B5").Select
    
    If Selection.Validation.Value Then
        Selection.Interior.ColorIndex = 0
    Else
        exceptionCount = exceptionCount + 1
        Selection.Interior.ColorIndex = 6
    End If
    
    'Validate PhiX
    Range("B11").Select
    
    If Selection.Validation.Value Then
        Selection.Interior.ColorIndex = 0
    Else
        exceptionCount = exceptionCount + 1
        Selection.Interior.ColorIndex = 6
    End If
    
    'Validate RGT Nr
    Range("B12").Select
    
    If Selection.Validation.Value And Len(Selection) = 11 And Selection <> Selection.Offset(1, 0) Then
        Selection.Interior.ColorIndex = 0
    Else
        exceptionCount = exceptionCount + 1
        Selection.Interior.ColorIndex = 6
    End If
    
    Range("B13").Select
    
    If Selection.Validation.Value And Len(Selection) = 11 And Selection <> Selection.Offset(-1, 0) Then
        Selection.Interior.ColorIndex = 0
    Else
        exceptionCount = exceptionCount + 1
        Selection.Interior.ColorIndex = 6
    End If
    
    'Validate MS Nr
    ThisWorkbook.Sheets("Sample Namen").Activate
    ActiveSheet.Unprotect
    Range("M8").Select
    
    If Selection.Validation.Value And Left(Selection, 2) = "MS" And Right(Selection, 6) = "-150V3" And Len(Selection) = 15 Then
        Selection.Interior.color = 11854022
    Else
        exceptionCount = exceptionCount + 1
        Selection.Interior.ColorIndex = 6
    End If
    ActiveSheet.Protect
    ThisWorkbook.Sheets("MiSeq SampleSheet").Activate
    
    'Validate Sample_ID
    Range("A25").Select
    Do Until ActiveCell.Value = vbNullString
    
    If Selection.Validation.Value Then
        Selection.Interior.ColorIndex = 0
    Else
        exceptionCount = exceptionCount + 1
        Selection.Interior.ColorIndex = 6
    End If
    
    Selection.Offset(1, 0).Select
    Loop
    
    'Validate Sample_Name
    Range("B25").Select
    Do Until ActiveCell.Value = vbNullString
    
    If Selection.Validation.Value Then
        Selection.Interior.ColorIndex = 0
    Else
        exceptionCount = exceptionCount + 1
        Selection.Interior.ColorIndex = 6
    End If
    
    Selection.Offset(1, 0).Select
    Loop
    
    'Validate I7_Index_ID
    Range("E25").Select
    Do Until ActiveCell.Value = vbNullString And Selection.Offset(0, -3) = vbNullString
    
    If Selection.Validation.Value Then
        Selection.Interior.ColorIndex = 0
    Else
        exceptionCount = exceptionCount + 1
        Selection.Interior.ColorIndex = 6
    End If
    
    Selection.Offset(1, 0).Select
    Loop
    
    'Validate I7_Index
    Range("F25").Select
    Do Until ActiveCell.Value = vbNullString And Selection.Offset(0, -4) = vbNullString
    
    If Selection.Validation.Value Then
        Selection.Interior.ColorIndex = 0
    Else
        exceptionCount = exceptionCount + 1
        Selection.Interior.ColorIndex = 6
    End If
    
    Selection.Offset(1, 0).Select
    Loop
    
    'Validate I5_Index_ID
    Range("G25").Select
    Do Until ActiveCell.Value = vbNullString And Selection.Offset(0, -5) = vbNullString
    
    If Selection.Validation.Value Then
        Selection.Interior.ColorIndex = 0
    Else
        exceptionCount = exceptionCount + 1
        Selection.Interior.ColorIndex = 6
    End If
    
    Selection.Offset(1, 0).Select
    Loop
    
    'Validate I5_Index
    Range("H25").Select
    Do Until ActiveCell.Value = vbNullString And Selection.Offset(0, -6) = vbNullString
    
    If Selection.Validation.Value Then
        Selection.Interior.ColorIndex = 0
    Else
        exceptionCount = exceptionCount + 1
        Selection.Interior.ColorIndex = 6
    End If
    
    Selection.Offset(1, 0).Select
    Loop
    
    'Validate Sample_Project
    Range("I25").Select
    Do Until ActiveCell.Value = vbNullString And Selection.Offset(0, -7) = vbNullString
    
    If Selection.Validation.Value Then
        Selection.Interior.ColorIndex = 0
    Else
        exceptionCount = exceptionCount + 1
        Selection.Interior.ColorIndex = 6
    End If
    
    Selection.Offset(1, 0).Select
    Loop
    
    'Validate virus
    Range("K25").Select
    Do Until ActiveCell.Value = vbNullString And Selection.Offset(0, -9) = vbNullString
    If Selection.Offset(0, -2) = "Resistance" Then
        If Selection.Validation.Value Then
            Selection.Interior.ColorIndex = 0
        Else
            exceptionCount = exceptionCount + 1
            Selection.Interior.ColorIndex = 6
        End If
    Else
        Selection.Interior.ColorIndex = 0
    End If
    
    Selection.Offset(1, 0).Select
    Loop
    
    'Validate genotype
    Range("L25").Select
    Do Until ActiveCell.Value = vbNullString And Selection.Offset(0, -10) = vbNullString
    
    If Selection.Offset(0, -3) = "Resistance" Then
        If Selection.Validation.Value Then
            Selection.Interior.ColorIndex = 0
        Else
            exceptionCount = exceptionCount + 1
            Selection.Interior.ColorIndex = 6
        End If
    Else
        Selection.Interior.ColorIndex = 0
    End If
    
    Selection.Offset(1, 0).Select
    Loop
    
    'Validate target
    Range("M25").Select
    Do Until ActiveCell.Value = vbNullString And Selection.Offset(0, -11) = vbNullString
    
    If Selection.Offset(0, -4) = "Resistance" Then
        If Selection.Validation.Value Then
            Selection.Interior.ColorIndex = 0
        Else
            exceptionCount = exceptionCount + 1
            Selection.Interior.ColorIndex = 6
        End If
    Else
        Selection.Interior.ColorIndex = 0
    End If
    
    Selection.Offset(1, 0).Select
    Loop
    
    'Validate viral_load
    Range("N25").Select
    Do Until ActiveCell.Value = vbNullString And Selection.Offset(0, -12) = vbNullString
    
    If ActiveCell.Value = vbNullString Then
        Selection.Interior.ColorIndex = 0
    ElseIf Selection.Validation.Value Then
        Selection.Interior.ColorIndex = 0
    Else
        exceptionCount = exceptionCount + 1
        Selection.Interior.ColorIndex = 6
    End If
    
    Selection.Offset(1, 0).Select
    Loop
    
    'Validate timavo
    Range("O25").Select
    Do Until ActiveCell.Value = vbNullString And Selection.Offset(0, -13) = vbNullString
    
    If Selection.Validation.Value Then
        Selection.Interior.ColorIndex = 0
    Else
        exceptionCount = exceptionCount + 1
        Selection.Interior.ColorIndex = 6
    End If
    
    Selection.Offset(1, 0).Select
    Loop
    
    
    
    If exceptionCount >= 1 Then
        MsgBox ("Das MiSeq SampleSheet ist nicht gültig!" & vbNewLine & _
        "Es enthält " & exceptionCount & " Fehler.")
        ActiveSheet.Protect
        Application.ScreenUpdating = True
    End If
    
    If exceptionCount = 0 Then
        ActiveSheet.Protect
        ThisWorkbook.Sheets("Sample Namen").Activate
        Application.ScreenUpdating = True
        MsgBox ("Das MiSeq SampleSheet ist gültig.")
    End If
    
    
    
End Sub
