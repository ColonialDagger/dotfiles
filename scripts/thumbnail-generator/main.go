package main

import (
    "bufio"
    "fmt"
    "image"
    "net/http"
    "os"
    "path/filepath"
    "strings"

    "github.com/fogleman/gg"
    "github.com/nfnt/resize"
)

func main() {
    // === Runtime Input ===
    reader := bufio.NewReader(os.Stdin)

    fmt.Print("Enter background image URL: ")
    bgURL, _ := reader.ReadString('\n')
    bgURL = strings.TrimSpace(bgURL)

    fmt.Print("Enter top line text: ")
    topText, _ := reader.ReadString('\n')
    topText = strings.TrimSpace(topText)

    fmt.Print("Enter middle line text: ")
    midText, _ := reader.ReadString('\n')
    midText = strings.TrimSpace(midText)

    fmt.Print("Enter bottom line text: ")
    bottomText, _ := reader.ReadString('\n')
    bottomText = strings.TrimSpace(bottomText)

    // === Load Background Image ===
    req, _ := http.NewRequest("GET", bgURL, nil)
	req.Header.Set("User-Agent", "Mozilla/5.0")
	resp, err := http.DefaultClient.Do(req)
    if err != nil {
        panic(err)
    }
    defer resp.Body.Close()
    bgImg, _, err := image.Decode(resp.Body)
    if err != nil {
        panic(err)
    }

    // Resize to 1280x720
    resizedImg := resize.Resize(1280, 720, bgImg, resize.Lanczos3)

    dc := gg.NewContext(1280, 720)
    dc.DrawImage(resizedImg, 0, 0)

    height := 720

    // === Load Font from ~/.local/share/fonts ===
    homeDir, err := os.UserHomeDir()
    if err != nil {
        panic(err)
    }
    fontPath := filepath.Join(homeDir, ".local", "share", "fonts", "BebasNeue-Regular.ttf")

    // === Helper: Draw Outlined Text (Left-Aligned) ===
    drawOutlinedText := func(text string, x, y float64, size float64) {
        if err := dc.LoadFontFace(fontPath, size); err != nil {
            panic(err)
        }
        // Outline
        dc.SetRGB(0, 0, 0)
        for dx := -2; dx <= 2; dx++ {
            for dy := -2; dy <= 2; dy++ {
                if dx != 0 || dy != 0 {
                    dc.DrawStringAnchored(text, x+float64(dx), y+float64(dy), 0.0, 1.0)
                }
            }
        }
        // Fill
        dc.SetRGB(1, 1, 1)
        dc.DrawStringAnchored(text, x, y, 0.0, 1.0)
    }

    // === Positioning and Sizes ===
    marginLeft := 6.0
    marginBottom := 10.0
    // lineSpacing := 26.0

    sizeBottom := 72.0
    sizeMid := 148.0
    sizeTop := 96.0

    yBottom := float64(height) - sizeBottom + marginBottom
    yMid := yBottom - sizeMid + 34.0  // Originally subtracted lineSpacing
    yTop := yMid - sizeTop + 24.0  // Originally subtracted lineSpacing

    drawOutlinedText(bottomText, marginLeft, yBottom, sizeBottom)
    drawOutlinedText(midText, marginLeft, yMid, sizeMid)
    drawOutlinedText(topText, marginLeft, yTop, sizeTop)

    // === Save Output ===
    dc.SavePNG("thumbnail.png")
    fmt.Println("Thumbnail saved as thumbnail.png")
}

