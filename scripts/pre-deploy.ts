import * as fs from "fs"
import * as path from "path"

const sourceDir = "./contracts"
const outputDir = "./contracts/dist"

// Ensure the output directory exists
if (!fs.existsSync(outputDir)) {
  fs.mkdirSync(outputDir, { recursive: true })
}

// Function to process file content
function processFileContent(content: string): string {
  const lines = content.split("\n")
  const modifiedLines: string[] = []

  lines.forEach((line, index) => {
    // Remove everything after ";;" in the line
    const cleanedLine = line.includes(";;") ? line.split(";;")[0] : line

    // Conditions for lines that should keep a newline
    if (
      cleanedLine.startsWith("(use-trait") ||
      cleanedLine.startsWith("(imp-trait") ||
      cleanedLine.startsWith("(define-") ||
      cleanedLine.startsWith("(map-set")
    ) {
      modifiedLines.push(cleanedLine) // Keep newline for these lines
    } else {
      // If there's a previous line and it's not empty, append this line to it
      if (modifiedLines.length > 0 && cleanedLine.trim()) {
        let lastLine = modifiedLines.pop() || ""

        // Ensure there's a space between lines when necessary
        if (!lastLine.endsWith(" ") && !lastLine.endsWith("\t")) {
          lastLine += " "
        }

        lastLine += cleanedLine.trim()
        modifiedLines.push(lastLine)
      } else {
        // modifiedLines.push(cleanedLine.trim())
      }
    }
  })

  return modifiedLines.join("\n")
}

// Function to read all files with the specified extension and process them
function processDirectoryFiles(sourceDir: string, outputDir: string) {
  const extension = ".clar"
  fs.readdir(sourceDir, (err, files) => {
    if (err) {
      console.error(`Error reading directory: ${err}`)
      return
    }

    files.forEach(file => {
      const sourceFilePath = path.join(sourceDir, file)
      const fileExtension = path.extname(file)

      if (fileExtension === extension) {
        fs.readFile(sourceFilePath, "utf8", (err, data) => {
          if (err) {
            console.error(`Error reading file: ${sourceFilePath}: ${err}`)
            return
          }

          const modifiedContent = processFileContent(data)
          console.log({ modifiedContent })
          const outputFilePath = path.join(outputDir, file)
          fs.writeFile(outputFilePath, modifiedContent, err => {
            if (err) {
              console.error(`Error writing file: ${outputFilePath}: ${err}`)
            } else {
              console.log(`Processed file written to: ${outputFilePath}`)
            }
          })
        })
      }
    })
  })
}

// Call the function with the desired extension
processDirectoryFiles(sourceDir, outputDir)
processDirectoryFiles(sourceDir + "/traits", outputDir)
