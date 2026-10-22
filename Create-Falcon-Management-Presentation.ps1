param(
    [string]$OutputPath = (Join-Path $PSScriptRoot 'Falcon-Management-Presentation.pptx')
)

$ErrorActionPreference = 'Stop'
$green = 0x364A0B
$greenDark = 0x272A09
$green2 = 0x4C7608
$gold = 0x228BBD
$ink = 0x272A09
$muted = 0x5B6253
$wash = 0xF2F5F1
$white = 0xFFFFFF
$line = 0xDCE1D9

function Add-Rect($slide, [int]$x, [int]$y, [int]$w, [int]$h, [int]$color, [int]$shapeType = 1) {
    $shape = $slide.Shapes.AddShape($shapeType, $x, $y, $w, $h)
    $shape.Fill.ForeColor.RGB = $color
    $shape.Line.Visible = 0
    return $shape
}

function Add-Text($slide, [string]$text, [int]$x, [int]$y, [int]$w, [int]$h, [single]$size, [int]$color, [bool]$bold = $false, [string]$font = 'Segoe UI') {
    $shape = $slide.Shapes.AddTextbox(1, $x, $y, $w, $h)
    $shape.TextFrame.WordWrap = -1
    $shape.TextFrame.MarginLeft = 0
    $shape.TextFrame.MarginRight = 0
    $shape.TextFrame.MarginTop = 0
    $shape.TextFrame.MarginBottom = 0
    $shape.TextFrame.VerticalAnchor = 1
    $range = $shape.TextFrame.TextRange
    $range.Text = $text
    $range.Font.Name = $font
    $range.Font.Size = $size
    $range.Font.Bold = [int]$bold
    $range.Font.Color.RGB = $color
    return $shape
}

function Add-Header($slide, [string]$label) {
    Add-Rect $slide 0 0 960 9 $gold | Out-Null
    Add-Rect $slide 0 9 960 54 $green | Out-Null
    Add-Rect $slide 48 20 31 31 $gold 9 | Out-Null
    Add-Text $slide 'F' 48 20 31 31 17 $greenDark $true | Out-Null
    Add-Text $slide 'FALCON' 91 20 160 30 16 $white $true | Out-Null
    Add-Text $slide $label 680 21 232 27 11 0xD0D7D3 $true | Out-Null
}

function Add-Footer($slide, [string]$page) {
    Add-Text $slide 'FALCON  /  DIB MANAGEMENT' 54 510 400 18 9 $green $true | Out-Null
    Add-Text $slide $page 882 510 28 18 9 $muted $false | Out-Null
}

function Add-Benefit($slide, [int]$x, [int]$y, [string]$number, [string]$title, [string]$body, [int]$accent) {
    Add-Rect $slide $x $y 405 126 $white | Out-Null
    Add-Rect $slide $x $y 405 4 $accent | Out-Null
    Add-Rect $slide ($x + 19) ($y + 22) 42 42 $accent 9 | Out-Null
    $numberColor = if ($accent -eq $gold) { $greenDark } else { $white }
    Add-Text $slide $number ($x + 19) ($y + 31) 42 20 13 $numberColor $true | Out-Null
    Add-Text $slide $title ($x + 78) ($y + 18) 300 30 17 $green $true | Out-Null
    Add-Text $slide $body ($x + 78) ($y + 52) 300 75 11 $muted $false | Out-Null
}

$powerPoint = $null
$presentation = $null
try {
    $powerPoint = New-Object -ComObject PowerPoint.Application
    $powerPoint.Visible = -1
    $presentation = $powerPoint.Presentations.Add()
    $presentation.PageSetup.SlideWidth = 960
    $presentation.PageSetup.SlideHeight = 540

    $slide1 = $presentation.Slides.Add(1, 12)
    $slide1.Background.Fill.ForeColor.RGB = $white
    Add-Header $slide1 'DIB MANAGEMENT OVERVIEW'
    Add-Rect $slide1 620 63 340 477 $wash | Out-Null
    Add-Text $slide1 'FINANCE PORTFOLIO CONTROL' 66 112 500 24 11 $green2 $true | Out-Null
    Add-Text $slide1 'One governed view\nfrom demand to payment.' 66 155 510 150 38 $green $true | Out-Null
    Add-Text $slide1 'Falcon brings project registration, PET decisions, OPEX/CAPEX commitments and invoices into one controlled portfolio workspace.' 68 320 490 86 17 $muted $false | Out-Null
    Add-Rect $slide1 68 430 42 3 $gold | Out-Null
    Add-Text $slide1 'Falcon Finance Portfolio  |  Management Briefing' 68 446 490 30 12 $ink $true | Out-Null

    Add-Text $slide1 'REGISTER' 666 113 235 22 12 $green $true | Out-Null
    Add-Text $slide1 'Projects and non-project OPEX' 666 137 235 34 11 $muted | Out-Null
    Add-Rect $slide1 676 177 3 30 $gold | Out-Null
    Add-Text $slide1 'REVIEW & APPROVE' 666 215 235 22 12 $green $true | Out-Null
    Add-Text $slide1 'PET ownership and decisions' 666 239 235 34 11 $muted | Out-Null
    Add-Rect $slide1 676 279 3 30 $green2 | Out-Null
    Add-Text $slide1 'CONTROL COMMITMENTS' 666 317 250 22 12 $green $true | Out-Null
    Add-Text $slide1 'Budget lines, vendors and funding' 666 341 248 34 11 $muted | Out-Null
    Add-Rect $slide1 676 381 3 30 $gold | Out-Null
    Add-Text $slide1 'TRACK SETTLEMENT' 666 419 235 22 12 $green $true | Out-Null
    Add-Text $slide1 'Invoices, documents and reporting' 666 443 248 34 11 $muted | Out-Null
    Add-Footer $slide1 '01 / 02'

    $slide2 = $presentation.Slides.Add(2, 12)
    $slide2.Background.Fill.ForeColor.RGB = $wash
    Add-Header $slide2 'MANAGEMENT BENEFITS'
    Add-Text $slide2 'A SHARED OPERATING PICTURE' 56 91 500 22 10 $green2 $true | Out-Null
    Add-Text $slide2 'Benefits for DIB Management' 56 119 570 48 30 $green $true | Out-Null
    Add-Text $slide2 'Connect request ownership, financial controls and execution evidence in one portfolio view.' 601 122 304 50 12 $muted | Out-Null

    Add-Benefit $slide2 56 190 '01' 'Portfolio visibility' 'See projects, PET status, budget lines and invoices together, with management reporting for portfolio review.' $green
    Add-Benefit $slide2 499 190 '02' 'Clear accountability' 'Route PETs through reviewer and approver stages, with assigned owners, decisions and workflow history.' $gold
    Add-Benefit $slide2 56 328 '03' 'Stronger financial control' 'Maintain CAPEX/OPEX sources and monitor approved budgets, commitments, available balances and invoice activity.' $gold
    Add-Benefit $slide2 499 328 '04' 'Traceable records' 'Keep supporting documents with requests and financial records; use role-based access for governed actions.' $green

    Add-Rect $slide2 56 466 4 27 $gold | Out-Null
    Add-Text $slide2 'MANAGEMENT OUTCOME' 72 467 178 18 9 $green $true | Out-Null
    Add-Text $slide2 'A consistent view of demand, approval progress and financial exposure to support informed oversight.' 245 464 651 26 11 $ink $false | Out-Null
    Add-Footer $slide2 '02 / 02'

    $fullPath = [System.IO.Path]::GetFullPath($OutputPath)
    $presentation.SaveAs($fullPath, 24)
    Write-Output "Created PowerPoint: $fullPath"
}
finally {
    if ($presentation -ne $null) { $presentation.Close() }
    if ($powerPoint -ne $null) { $powerPoint.Quit() }
    if ($presentation -ne $null) { [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($presentation) }
    if ($powerPoint -ne $null) { [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($powerPoint) }
    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()
}
