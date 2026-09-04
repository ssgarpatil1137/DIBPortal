using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Packaging;
using System.Linq;
using System.Xml;

namespace DFM.Web.Infrastructure
{
    public static class SpreadsheetTableReader
    {
        private const string SpreadsheetNs = "http://schemas.openxmlformats.org/spreadsheetml/2006/main";

        public static List<List<string>> Read(Stream stream)
        {
            return ReadWorksheets(stream).FirstOrDefault(rows => rows.Any(row => row.Any(cell => !string.IsNullOrWhiteSpace(cell)))) ?? new List<List<string>>();
        }

        public static List<List<List<string>>> ReadWorksheets(Stream stream)
        {
            using (var package = Package.Open(stream, FileMode.Open, FileAccess.Read))
            {
                var sharedStrings = ReadSharedStrings(package);
                return Worksheets(package).Select(sheetPart => ReadWorksheet(sheetPart, sharedStrings)).ToList();
            }
        }

        private static IEnumerable<PackagePart> Worksheets(Package package)
        {
            var workbookUri = new Uri("/xl/workbook.xml", UriKind.Relative);
            if (!package.PartExists(workbookUri)) throw new ArgumentException("The Excel workbook does not contain xl/workbook.xml.");
            var workbook = package.GetPart(workbookUri);
            var relationships = workbook.GetRelationshipsByType("http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet").ToList();
            if (relationships.Count == 0) throw new ArgumentException("The Excel workbook does not contain a worksheet.");
            return relationships.Select(relationship => package.GetPart(PackUriHelper.ResolvePartUri(workbook.Uri, relationship.TargetUri)));
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

        private static List<List<string>> ReadWorksheet(PackagePart sheetPart, List<string> sharedStrings)
        {
            var document = LoadXml(sheetPart);
            var manager = NamespaceManager(document);
            var rows = new List<List<string>>();
            foreach (XmlNode rowNode in document.SelectNodes("//x:sheetData/x:row", manager))
            {
                var row = new List<string>();
                foreach (XmlNode cell in rowNode.SelectNodes("x:c", manager))
                {
                    var columnIndex = ColumnIndex(cell.Attributes["r"] == null ? null : cell.Attributes["r"].Value);
                    while (row.Count < columnIndex) row.Add("");
                    row.Add(CellValue(cell, manager, sharedStrings));
                }
                while (row.Count > 0 && string.IsNullOrWhiteSpace(row[row.Count - 1])) row.RemoveAt(row.Count - 1);
                rows.Add(row);
            }
            return rows;
        }

        private static string CellValue(XmlNode cell, XmlNamespaceManager manager, List<string> sharedStrings)
        {
            var type = cell.Attributes["t"] == null ? "" : cell.Attributes["t"].Value;
            if (type == "inlineStr")
            {
                var inlineText = cell.SelectNodes(".//x:t", manager).Cast<XmlNode>().Select(node => node.InnerText);
                return string.Join("", inlineText);
            }
            var valueNode = cell.SelectSingleNode("x:v", manager);
            var value = valueNode == null ? "" : valueNode.InnerText;
            if (type == "s")
            {
                int index;
                return int.TryParse(value, out index) && index >= 0 && index < sharedStrings.Count ? sharedStrings[index] : "";
            }
            if (type == "b") return value == "1" ? "TRUE" : "FALSE";
            return value;
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