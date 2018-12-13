package de.axxepta.syncrovet.api;

import de.axxepta.syncrovet.conversion.JsonXml;
import de.axxepta.syncrovet.daemon.RequestDaemon;
import de.axxepta.syncrovet.http.HTTPWrapper;

import java.io.*;
import java.util.HashMap;
import java.util.Map;

public class Shopware {

    private static Map<String, RequestDaemon> shopDaemons = new HashMap<>();

    public static String getShopwareXml(String protocol, String host, int port, String path, String user, String password,
                                                 String file, String[] parameters) {
        try {
            String xml = HTTPWrapper.getXmlFromJSON(protocol, host, port, path, user, password);
            String info = "";
            if (xml.contains("<data>")) {
                int dataBegin = xml.indexOf("<data>");
                int dataEnd = xml.lastIndexOf("</data>") + 7;
                info = xml.substring(0, dataBegin) + xml.substring(dataEnd);
                xml = xml.substring(dataBegin, dataEnd);
                xml = "<" + parameters[1] + ">" +
                        xml.replace("data>", parameters[0] + ">") + "</" + parameters[1] + ">";
            }
            if (file.length() > 0) {
                try {
                    JsonXml.WriteXmlStringToFile(xml, file);
                } catch (IOException ex) {
                    return ex.getMessage();
                }
                return info;
            }
            return xml;
        } catch (Exception ex) {
            return "<exception>" + ex.getMessage() + "</exception>";
        }
    }

    public static String putShopwareXml(String protocol, String host, int port, String path, String user, String password,
                                        String file, String[] parameters) {
        //
        return "<success>true</true>";
    }

    public static String startShopDaemon(String protocol, String host, int port, String path, String user, String password,
                                     String file, String[] parameters, long updateInterval, boolean uploading, String type) {
        if (!shopDaemons.containsKey(type) || !shopDaemons.get(type).isAlive()) {
            shopDaemons.put(type,
                    uploading ?
                        new RequestDaemon<>(host, port, path, user, password, file, parameters, updateInterval,
                                (fHost, fPort, fPath, fUser, fPassword, fFile, fParameters) ->
                                        putShopwareXml(protocol, fHost, fPort, fPath, fUser, fPassword, (String) fFile, fParameters)
                            ) :
                        new RequestDaemon<>(host, port, path, user, password, file, parameters, updateInterval,
                                (fHost, fPort, fPath, fUser, fPassword, fFile, fParameters) ->
                                        getShopwareXml(protocol, fHost, fPort, fPath, fUser, fPassword, (String) fFile, fParameters)
                            )
            );
            return "<started>true</started>";
        } else {
            return "<started>false</started>";
        }
    }

    public static String stopShopDaemon(String type) {
        if (shopDaemons.containsKey(type) && shopDaemons.get(type).isAlive()) {
            shopDaemons.get(type).interrupt();
            return "<stopped>true</stopped>";
        } else {
            return "<stopped>false</stopped>";
        }
    }


    public static String isShopDaemonRunning(String type) {
        if (shopDaemons.containsKey(type) && shopDaemons.get(type).isAlive()) {
            return "<running>true</running>";
        } else {
            return "<running>false</running>";
        }
    }

}
