"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
var fs = require("fs");
var path = require("path");
var sourceDir = "./contracts";
var outputDir = "./contracts/dist";
// Ensure the output directory exists
if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
}
// Function to process file content
function processFileContent(content) {
    var lines = content.split("\n");
    var modifiedLines = [];
    lines.forEach(function (line, index) {
        // Remove everything after ";;" in the line
        var cleanedLine = line.includes(";;") ? line.split(";;")[0] : line;
        // Conditions for lines that should keep a newline
        if (cleanedLine.startsWith("(use-trait") ||
            cleanedLine.startsWith("(imp-trait") ||
            cleanedLine.startsWith("(define-") ||
            cleanedLine.startsWith("(map-set")) {
            modifiedLines.push(cleanedLine); // Keep newline for these lines
        }
        else {
            // If there's a previous line and it's not empty, append this line to it
            if (modifiedLines.length > 0 && cleanedLine.trim()) {
                var lastLine = modifiedLines.pop() || "";
                // Ensure there's a space between lines when necessary
                if (!lastLine.endsWith(" ") && !lastLine.endsWith("\t")) {
                    lastLine += " ";
                }
                lastLine += cleanedLine.trim();
                modifiedLines.push(lastLine);
            }
            else {
                // modifiedLines.push(cleanedLine.trim())
            }
        }
    });
    return modifiedLines.join("\n");
}
// Function to read all files with the specified extension and process them
function processDirectoryFiles(sourceDir, outputDir) {
    var extension = ".clar";
    fs.readdir(sourceDir, function (err, files) {
        if (err) {
            console.error("Error reading directory: ".concat(err));
            return;
        }
        files.forEach(function (file) {
            var sourceFilePath = path.join(sourceDir, file);
            var fileExtension = path.extname(file);
            if (fileExtension === extension) {
                fs.readFile(sourceFilePath, "utf8", function (err, data) {
                    if (err) {
                        console.error("Error reading file: ".concat(sourceFilePath, ": ").concat(err));
                        return;
                    }
                    var modifiedContent = processFileContent(data);
                    console.log({ modifiedContent: modifiedContent });
                    var outputFilePath = path.join(outputDir, file);
                    fs.writeFile(outputFilePath, modifiedContent, function (err) {
                        if (err) {
                            console.error("Error writing file: ".concat(outputFilePath, ": ").concat(err));
                        }
                        else {
                            console.log("Processed file written to: ".concat(outputFilePath));
                        }
                    });
                });
            }
        });
    });
}
// Call the function with the desired extension
processDirectoryFiles(sourceDir, outputDir);
processDirectoryFiles(sourceDir + "/traits", outputDir);
