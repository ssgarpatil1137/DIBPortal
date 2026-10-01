using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.IO.Packaging;
using System.Linq;
using System.Xml;

namespace DFM.Web.Infrastructure
{
    public static class SpreadsheetTableReader
    {
        private const string SpreadsheetNs = "http://schemas.openxmlformats.org/spreadsheetml/2006/main";
        private const string RelationshipNs = "http://schemas.openxmlformats.org/officeDocument/2006/relationships";

        public static List<List<string>> Read(Stream stream)
        {
            return ReadWorksheets(stream).FirstOrDefault(rows => rows.Any(row => row.Any(cell => !string.IsNullOrWhiteSpace(cell)))) ?? new List<List<string>>();
        }

        public static List<List<List<string>>> ReadWorksheets(Stream stream)
        {
            using (var package = Package.Open(stream, FileMode.Open, FileAccess.Read))
            {
                var sharedStrings = ReadSharedStrings(package);
                var styles = ReadStyles(package);
                return Worksheets(package).Select(sheet => ReadWorksheet(sheet.Part, sharedStrings, styles)).ToList();
            }
        }

        private sealed class WorksheetInfo
        {
            public string Name { get; set; }
            public PackagePart Part { get; set; }
            public int Index { get; set; }
        }

        private sealed class WorkbookStyles
        {
            public readonly HashSet<int> DateStyleIndexes = new HashSet<int>();
            public readonly HashSet<int> PercentStyleIndexes = new HashSet<int>();
        }

        private static IEnumerable<WorksheetInfo> Worksheets(Package package)
        {
            var workbookUri = new Uri("/xl/workbook.xml", UriKind.Relative);
            if (!package.PartExists(workbookUri)) throw new ArgumentException("The Excel workbook does not contain xl/workbook.xml.");
            var workbook = package.GetPart(workbookUri);
            var document = LoadXml(workbook);
            var manager = NamespaceManager(document);
            manager.AddNamespace("r", RelationshipNs);
            var sheets = new List<WorksheetInfo>();
            var index = 0;
            foreach (XmlNode sheet in document.SelectNodes("//x:sheets/x:sheet", manager))
            {
                var relationshipId = sheet.Attributes["r:id"] == null ? null : sheet.Attributes["r:id"].Value;
                if (string.IsNullOrWhiteSpace(relationshipId)) continue;
                var relationship = workbook.GetRelationship(relationshipId);
                sheets.Add(new WorksheetInfo
                {
                    Name = sheet.Attributes["name"] == null ? "" : sheet.Attributes["name"].Value,
                    Part = package.GetPart(PackUriHelper.ResolvePartUri(workbook.Uri, relationship.TargetUri)),
                    Index = index++
                });
            }
            if (sheets.Count == 0) throw new ArgumentException("The Excel workbook does not contain a worksheet.");
            return sheets.OrderBy(sheet => sheet.Name.Equals("Budget", StringComparison.OrdinalIgnoreCase) ? 0 : 1).ThenBy(sheet => sheet.Index);
        }

        private static List<string> ReadSharedStrings(Package package)
        {
            var sharedUri = new Uri("/xl/sharedStrings.xml", UriKind.Relative);
            var values = new List<string>();
            if (!package.PartExists(sharedUri)) return values;
            var document = LoadXml(package.GetPart(sharedUri));
            var manager = NamespaceManager(document);
            foreach (XmlNode item in document.SelectNodes("//x:si", manager))
            {
                var parts = item.SelectNodes(".//x:t", manager).Cast<XmlNode>().Select(node => node.InnerText);
                values.Add(string.Join("", parts));
            }
            return values;
        }

        private static WorkbookStyles ReadStyles(Package package)
        {
            var styles = new WorkbookStyles();
            var stylesUri = new Uri("/xl/styles.xml", UriKind.Relative);
            if (!package.PartExists(stylesUri)) return styles;
            var document = LoadXml(package.GetPart(stylesUri));
            var manager = NamespaceManager(document);
            var customDateFormats = new HashSet<int>();
            var customPercentFormats = new HashSet<int>();
            foreach (XmlNode format in document.SelectNodes("//x:numFmts/x:numFmt", manager))
            {
                int formatId;
                if (!int.TryParse(format.Attributes["numFmtId"] == null ? null : format.Attributes["numFmtId"].Value, out formatId)) continue;
                var code = format.Attributes["formatCode"] == null ? "" : format.Attributes["formatCode"].Value;
                if (LooksLikeDateFormat(code)) customDateFormats.Add(formatId);
                if (code.IndexOf('%') >= 0) customPercentFormats.Add(formatId);
            }
            var styleIndex = 0;
            foreach (XmlNode format in document.SelectNodes("//x:cellXfs/x:xf", manager))
            {
                int formatId;
                if (int.TryParse(format.Attributes["numFmtId"] == null ? null : format.Attributes["numFmtId"].Value, out formatId))
                {
                    if (IsBuiltInDateFormat(formatId) || customDateFormats.Contains(formatId)) styles.DateStyleIndexes.Add(styleIndex);
                    if (formatId == 9 || formatId == 10 || customPercentFormats.Contains(formatId)) styles.PercentStyleIndexes.Add(styleIndex);
                }
                styleIndex++;
            }
            return styles;
        }

        private static bool IsBuiltInDateFormat(int formatId)
        {
            return (formatId >= 14 && formatId <= 22) || (formatId >= 27 && formatId <= 36) || (formatId >= 45 && formatId <= 47) || (formatId >= 50 && formatId <= 58);
        }

        private static bool LooksLikeDateFormat(string formatCode)
        {
            var code = (formatCode ?? "").ToLowerInvariant();
            return (code.IndexOf('y') >= 0 || code.IndexOf('d') >= 0) && code.IndexOf(";") < 0;
        }

        private static List<List<string>> ReadWorksheet(PackagePart sheetPart, List<string> sharedStrings, WorkbookStyles styles)
        {
            var document = LoadXml(sheetPart);
            var manager = NamespaceManager(document);
            var hiddenColumns = HiddenColumns(document, manager);
            var rows = new List<List<string>>();
            foreach (XmlNode rowNode in document.SelectNodes("//x:sheetData/x:row", manager))
            {
                var row = new List<string>();
                foreach (XmlNode cell in rowNode.SelectNodes("x:c", manager))
                {
                    var columnIndex = ColumnIndex(cell.Attributes["r"] == null ? null : cell.Attributes["r"].Value);
                    if (hiddenColumns.Contains(columnIndex)) continue;
                    var visibleColumnIndex = VisibleColumnIndex(columnIndex, hiddenColumns);
                    while (row.Count < visibleColumnIndex) row.Add("");
                    row.Add(CellValue(cell, manager, sharedStrings, styles));
                }
                while (row.Count > 0 && string.IsNullOrWhiteSpace(row[row.Count - 1])) row.RemoveAt(row.Count - 1);
                rows.Add(row);
            }
            return rows;
        }

        private static HashSet<int> HiddenColumns(XmlDocument document, XmlNamespaceManager manager)
        {
            var hiddenColumns = new HashSet<int>();
            foreach (XmlNode column in document.SelectNodes("//x:cols/x:col", manager))
            {
                var hidden = column.Attributes["hidden"] == null ? "" : column.Attributes["hidden"].Value;
                if (hidden != "1" && !hidden.Equals("true", StringComparison.OrdinalIgnoreCase)) continue;
                int min;
                int max;
                if (!int.TryParse(column.Attributes["min"] == null ? null : column.Attributes["min"].Value, out min)) continue;
                if (!int.TryParse(column.Attributes["max"] == null ? null : column.Attributes["max"].Value, out max)) max = min;
                for (var index = min; index <= max; index++) hiddenColumns.Add(index - 1);
            }
            return hiddenColumns;
        }

        private static int VisibleColumnIndex(int columnIndex, HashSet<int> hiddenColumns)
        {
            return Math.Max(columnIndex - hiddenColumns.Count(hiddenColumn => hiddenColumn < columnIndex), 0);
        }

        private static string CellValue(XmlNode cell, XmlNamespaceManager manager, List<string> sharedStrings, WorkbookStyles styles)
        {
            var type = cell.Attributes["t"] == null ? "" : cell.Attributes["t"].Value;
            if (type == "inlineStr")
            {
                var inlineText = cell.SelectNodes(".//x:t", manager).Cast<XmlNode>().Select(node => node.InnerText);
                return string.Join("", inlineText);
            }
            var valueNode = cell.SelectSingleNode("x:v", manager);
            var value = valueNode == null ? "" : valueNode.InnerText;
            if (type == "d")
            {
                DateTime date;
                return DateTime.TryParse(value, CultureInfo.InvariantCulture, DateTimeStyles.None, out date) ? date.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture) : value;
            }
            if (type == "s")
            {
                int index;
                return int.TryParse(value, out index) && index >= 0 && index < sharedStrings.Count ? sharedStrings[index] : "";
            }
            if (type == "b") return value == "1" ? "TRUE" : "FALSE";
            var styleIndex = CellStyleIndex(cell);
            double numericValue;
            if (styleIndex.HasValue && double.TryParse(value, NumberStyles.Float, CultureInfo.InvariantCulture, out numericValue))
            {
                if (styles.DateStyleIndexes.Contains(styleIndex.Value))
                {
                    try { return DateTime.FromOADate(numericValue).ToString("yyyy-MM-dd", CultureInfo.InvariantCulture); }
                    catch (ArgumentException) { }
                }
                if (styles.PercentStyleIndexes.Contains(styleIndex.Value)) return (numericValue * 100).ToString("0.########", CultureInfo.InvariantCulture);
            }
            return value;
        }

        private static int? CellStyleIndex(XmlNode cell)
        {
            int styleIndex;
            return int.TryParse(cell.Attributes["s"] == null ? null : cell.Attributes["s"].Value, out styleIndex) ? (int?)styleIndex : null;
        }

        private static int ColumnIndex(string reference)
        {
            if (string.IsNullOrWhiteSpace(reference)) return 0;
            var index = 0;
            foreach (var character in reference.TakeWhile(char.IsLetter))
                index = index * 26 + (char.ToUpperInvariant(character) - 'A' + 1);
            return Math.Max(index - 1, 0);
        }

        private static XmlDocument LoadXml(PackagePart part)
        {
            var document = new XmlDocument { PreserveWhitespace = false };
            using (var stream = part.GetStream(FileMode.Open, FileAccess.Read)) document.Load(stream);
            return document;
        }

        private static XmlNamespaceManager NamespaceManager(XmlDocument document)
        {
            var manager = new XmlNamespaceManager(document.NameTable);
            manager.AddNamespace("x", SpreadsheetNs);
            return manager;
        }
    }
}