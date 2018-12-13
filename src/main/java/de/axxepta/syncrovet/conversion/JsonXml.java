package de.axxepta.syncrovet.conversion;

import org.json.JSONObject;
import org.json.XML;

import java.io.*;
import java.nio.file.Files;
import java.nio.file.Paths;

public class JsonXml {

    public static String JsonToXmlString(String str) {
        JSONObject json = new JSONObject(str);
        return XML.toString(json);

    }

    public static String XmlToJsonString(String str) {
        JSONObject json = XML.toJSONObject(str);
        return json.toString();
    }

    public static String JsonToXmlFile(String jsonFile, String xmlFile, String encoding) {
        String json = "";
        try {
            json = new String(Files.readAllBytes(Paths.get(jsonFile)), encoding);
        } catch (IOException ex) {
            return "<exception>Couldn't read file</exception>";
        }
        String xml = "";
        try {
            xml = JsonToXmlString(json);
        } catch (Exception ex) {
            return "<error><exception>" + ex.getMessage() + "</exception><JSON>" + json + "</JSON></error>";
        }
        try {
            return WriteXmlStringToFile(xml, xmlFile);
        } catch (IOException ex) {
            return "<exception>" + ex.getMessage() + "</exception>";
        }
    }

    public static String WriteXmlStringToFile(String xml, String xmlFile) throws IOException {
        try (Writer out = new BufferedWriter(new OutputStreamWriter(
                new FileOutputStream(xmlFile), "UTF-8"))) {
            out.write("<?xml version=\"1.0\" encoding=\"UTF-8\"?>");
            out.write(System.getProperty("line.separator"));
            out.write(xml);
            return xml;
        }
    }
}
