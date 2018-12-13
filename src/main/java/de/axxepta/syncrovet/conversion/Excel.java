package de.axxepta.syncrovet.conversion;

import org.apache.poi.hssf.util.CellReference;
import org.apache.poi.ss.usermodel.*;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;

import javax.xml.stream.XMLOutputFactory;
import javax.xml.stream.XMLStreamException;
import javax.xml.stream.XMLStreamWriter;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.StringWriter;
import java.util.*;

public class Excel {

    public static String excelSheetToHTMLString(String fileName, String sheetName, boolean firstRowHead) {
        StringBuilder builder = new StringBuilder();
        builder.append("<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Transitional//EN\"" +
                " \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd\">")
                .append("<html xmlns=\"http://www.w3.org/1999/xhtml\">")
                .append("<head><title>").append(sheetName).append("</title></head>")
                .append("<body>");
        try (FileInputStream file = new FileInputStream(fileName)) {
            Workbook workbook = new XSSFWorkbook(file);
            Sheet sheet = workbook.getSheet(sheetName);
            DataFormatter formatter = new DataFormatter(true);
            int firstRow = sheet.getFirstRowNum();
            int lastRow = sheet.getLastRowNum();
            int firstColumn = Math.min(sheet.getRow(firstRow).getFirstCellNum(), sheet.getRow(firstRow + 1).getFirstCellNum());
            int lastColumn = Math.max(sheet.getRow(firstRow).getLastCellNum(), sheet.getRow(firstRow + 1).getLastCellNum());

            builder.append("<table>");
            for (int rowNumber = firstRow; rowNumber < lastRow + 1; rowNumber++) {
                builder.append("<tr>");
                Row row = sheet.getRow(rowNumber);
                for (int colNumber = firstColumn; colNumber < lastColumn; colNumber++) {
                    builder.append((firstRowHead && (rowNumber == firstRow)) ? "<th>" : "<td>");
                    Cell cell = row.getCell(colNumber);
                    builder.append(formatter.formatCellValue(cell).
                            replaceAll("&", "&amp;").replaceAll("<", "&lt;").
                            replaceAll(">", "&gt;"));
                    builder.append((firstRowHead && (colNumber == firstColumn)) ? "</th>" : "</td>");
                }
                builder.append("</tr>");
            }
            builder.append("</table>");
            builder.append("</body></html>");

        } catch (IOException ie) {
            builder.append("</body></html>");
        }
        return builder.toString();
    }


    public static String excelSheetTransformString(String fileName, String sheetName, String root,
                                             String nlSeparatedMappingList, boolean firstRowHead) {
        List<String[]> mapping = listToLinkedMap(nlSeparatedMappingList);
        XMLOutputFactory factory = XMLOutputFactory.newInstance();
        StringWriter result = new StringWriter();
        try(FileInputStream file = new FileInputStream(fileName)) {
            XMLStreamWriter writer = factory.createXMLStreamWriter(result);
            Workbook workbook = new XSSFWorkbook(file);
            Sheet sheet = workbook.getSheet(sheetName);
            DataFormatter formatter = new DataFormatter(true);
            int firstRow = sheet.getFirstRowNum();
            int lastRow = sheet.getLastRowNum();
            int firstColumn = Math.min(sheet.getRow(firstRow).getFirstCellNum(),
                    sheet.getRow(firstRow + 1).getFirstCellNum());
            int lastColumn = Math.max(sheet.getRow(firstRow).getLastCellNum(),
                    sheet.getRow(firstRow + 1).getLastCellNum());

            List<String> headers = new ArrayList<>();
            Row row1 = sheet.getRow(firstRow);
            for (int colNumber = firstColumn; colNumber < lastColumn; colNumber++) {
                headers.add(firstRowHead ? formatter.formatCellValue(row1.getCell(colNumber)):
                        CellReference.convertNumToColString(row1.getCell(colNumber).getColumnIndex()));
            }

            writer.writeStartDocument();
            writer.writeStartElement(root);
            for (int rowNumber = firstRow + (firstRowHead ? 1 : 0); rowNumber < lastRow + 1; rowNumber++) {
                Row row = sheet.getRow(rowNumber);

                int[] openElements = {0};
                String[] lastElement = {""};
                mapping.forEach(k -> {
                    int col = headers.indexOf(k[0]) + firstColumn;
                    if (col > firstColumn - 1) {
                        try {
                            Cell cell = row.getCell(col);
                            String val = formatter.formatCellValue(cell).
                                    replaceAll("&", "&amp;").replaceAll("<", "&lt;").
                                    replaceAll(">", "&gt;");
                            String[][] diff = pathDiff(lastElement[0], k[1]);
                            closeWriterElements(writer, diff[0].length - (lastElement[0].contains("@") ? 1 :0));
                            for (int e = 0; e < diff[1].length; e++) {
                                if (diff[1][e].startsWith("@")) {
                                    writer.writeAttribute(diff[1][e].substring(1), val);
                                } else {
                                    writer.writeStartElement(diff[1][e]);
                                    if (e == diff[1].length - 1)
                                        writer.writeCharacters(val);
                                }
                            }
                            if (diff[1].length == 0)
                                writer.writeCharacters(val);
                            lastElement[0] = k[1];
                            String[] lastPath = k[1].split("/");
                            openElements[0] = lastPath.length - (lastPath[lastPath.length - 1].startsWith("@") ? 1 : 0);
                        } catch (XMLStreamException | IllegalArgumentException xs) {}
                    }
                });

                closeWriterElements(writer, openElements[0]);
            }
            writer.writeEndElement();
            writer.writeEndDocument();
            writer.close();

        } catch (XMLStreamException|IOException xe) {
            return "<xml-transformation-error>" + xe.getMessage(). replaceAll("&", "&amp;").
                    replaceAll("<", "&lt;").replaceAll(">", "&gt;") +
                    "<xml-transformation-error>";
        }
        return result.toString();
    }


    private static String[][] pathDiff(String last, String current) throws IllegalArgumentException {
        if (last.equals(current))
            throw new IllegalArgumentException("Consecutive path definitions must not be equal.");
        String[][] diff = {new String[0], new String[0]};
        String[] old = (last.equals("")) ? new String[0] : last.split("/");
        String[] neww = current.split("/");
        int minLength = Math.min(old.length, neww.length);
        if (old.length == 0)
            diff[1] = neww;
        for (int i = 0; i < minLength; i++) {
            if (!old[i].equals(neww[i])) {
                diff[0] = Arrays.copyOfRange(old, i, old.length);
                diff[1] = Arrays.copyOfRange(neww, i, neww.length);
                break;
            }
            if (i + 1 == minLength) {
                diff[0] = (old.length > minLength) ?
                        Arrays.copyOfRange(old, minLength, old.length) : new String[0];
                diff[1] = (neww.length > minLength) ?
                        Arrays.copyOfRange(neww, minLength, neww.length) : new String[0];
            }
        }
        return diff;
    }


    private static void closeWriterElements(XMLStreamWriter writer, int num) throws XMLStreamException {
        for (int i = 0; i < num; i++) writer.writeEndElement();
    }

    private static List<String[]> listToLinkedMap(String nlMappingList) {
        String[] mappingList = nlMappingList.split("\\r?\\n");
        List<String[]> map = new LinkedList<>();
        for (String mapLine : mappingList) {
            if (!mapLine.equals("")) {
                String[] entry = mapLine.split("\\t");
                map.add(new String[]{entry[0], entry[1]});
            }
        }
        return map;
    }

}