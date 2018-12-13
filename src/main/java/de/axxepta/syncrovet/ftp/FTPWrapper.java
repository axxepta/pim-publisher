package de.axxepta.syncrovet.ftp;

import org.apache.commons.net.ftp.FTPClient;
import org.apache.commons.net.ftp.FTPFile;
import org.apache.commons.net.ftp.FTPHTTPClient;

import java.io.*;
import java.net.*;
import java.util.Arrays;



public class FTPWrapper {

    public static final int BUFFER_SIZE = 4096;

    private static FTPClient getFTPClient(String proxyHost, int proxyPort) {
        if (proxyHost.equals("")) {
            return new FTPClient();
        } else {
            return new FTPHTTPClient(proxyHost, proxyPort);
        }
    }

    public static String list(String user, String pwd, String server, int port, String path,
                              String proxyHost, int proxyPort) {
        FTPClient ftpClient = getFTPClient(proxyHost, proxyPort);
        StringBuilder builder = new StringBuilder("<ftp path=\"").append(path).append("\">");
        try {
            ftpClient.enterLocalPassiveMode();
            ftpClient.connect(server, port);
            ftpClient.login(user, pwd);
            FTPFile[] dirs  = ftpClient.listDirectories(path);
            FTPFile[] files = ftpClient.listFiles(path);
            Arrays.stream(dirs).forEach(e->builder.append("<dir>").append(e.getName()).append("</dir>"));
            Arrays.stream(files).forEach(e->builder.append("<file>").append(e.getName()).append("</file>"));
        } catch (IOException e) {
            e.printStackTrace();
            builder.append("<error>").append(e.getMessage()).append("</error>");
        } finally {
            try {
                ftpClient.logout();
                ftpClient.disconnect();
            } catch (IOException x) {
                x.printStackTrace();
            }
        }
        return builder.append("</ftp>").toString();
    }

    public static String delete(String user, String pwd, String server, int port, String path,
                                String proxyHost, int proxyPort) {
        FTPClient ftpClient = getFTPClient(proxyHost, proxyPort);
        StringBuilder builder =
                new StringBuilder("<ftp delete=\"").append(path).append("\">");
        try {
            ftpClient.connect(server, port);
            ftpClient.login(user, pwd);
            ftpClient.deleteFile(path);
        } catch (IOException e) {
            e.printStackTrace();
            builder.append("<error>").append(e.getMessage()).append("</error>");
        } finally {
            try {
                ftpClient.logout();
                ftpClient.disconnect();
            } catch (IOException x) {
                x.printStackTrace();
            }
        }
        return builder.append("</ftp>").toString();
    }


    public static String move(String user, String pwd, String server, int port, String from, String to,
                              String proxyHost, int proxyPort) {
        FTPClient ftpClient = getFTPClient(proxyHost, proxyPort);
        StringBuilder builder =
                new StringBuilder("<ftp from='").append(from).append("' to='").append(to).append("'>");
        try {
            ftpClient.connect(server, port);
            ftpClient.login(user, pwd);
            ftpClient.rename(from, to);
        } catch (IOException e) {
            e.printStackTrace();
            builder.append("<error>").append(e.getMessage()).append("</error>");
        } finally {
            try {
                ftpClient.logout();
                ftpClient.disconnect();
            } catch (IOException x) {
                x.printStackTrace();
            }
        }
        return builder.append("</ftp>").toString();
    }

    public static String copy(String user, String pwd, String server, String from, String to) {
        StringBuilder builder =
                new StringBuilder("<ftp from='").append(from).append("' to='").append(to).append("'>");
        try {
            byte[] backup = downloadBytes(user, pwd, server, from);
            uploadBytes(user, pwd, server, to, backup);
        } catch (IOException e) {
            e.printStackTrace();
            builder.append("<error>").append(e.getMessage()).append("</error>");
        }
        return builder.append("</ftp>").toString();
    }

    public static String download(String user, String pwd, String server, String path, String storePath) {
        try {
            URL url = new URL("ftp://" + user + ":" + pwd + "@" + server + path);
            save(url, storePath);
            return "<success>Downloaded " + "ftp://" + server + path + " to " + storePath + "</success>";
        } catch (IOException e) {
            e.printStackTrace();
            return "<fatal>" + e.getMessage() + "</fatal>";
        }
    }

    private static void save(URL url, String fileName) throws IOException {
        try (InputStream is = url.openStream()) {

            try (OutputStream os =
                    new FileOutputStream(new File(fileName)) ) {

                int read;
                byte[] bytes = new byte[BUFFER_SIZE];

                while ((read = is.read(bytes)) != -1) {
                    os.write(bytes, 0, read);
                }
            }
        }
    }

    private static ByteArrayOutputStream download(String user, String pwd, String server, String path) throws IOException {
        URL url = new URL("ftp://" + user + ":" + pwd + "@" + server + path);
        ByteArrayOutputStream os = new ByteArrayOutputStream();
        try (InputStream is = url.openStream()) {
            int read;
            byte[] bytes = new byte[BUFFER_SIZE];
            while ((read = is.read(bytes)) != -1) {
                os.write(bytes, 0, read);
            }
        }
        return os;
    }

    public static String remove(String user, String pwd, String server, String path) {
        try {
            int pathDelimiter = path.lastIndexOf("/");
            String dir = path.substring(0, pathDelimiter + 1);
            String file = path.substring(pathDelimiter + 1);
            URL url = new URL("ftp://" + user + ":" + pwd + "@" + server + path + ";type=i");
            //URL url = new URL("ftp://" + user + ":" + pwd + "@" + server + path + ";type=i");
            URLConnection urlConnection = url.openConnection();
            try (PrintStream ps = new PrintStream((urlConnection.getOutputStream()))) {
                ps.println("del " + path);
                //ps.println("RMD " + path);
            }
            return "<ftp delete=\"" + path + "\"></ftp>";
        } catch (IOException e) {
            e.printStackTrace();
            return "<error>" + e.getMessage() + "</error>";
        }
    }

    public static String dir(String user, String pwd, String server, String path) {
        try {
            URL url = new URL("ftp://" + user + ":" + pwd + "@" + server + path + ";type=d");
            URLConnection urlConnection = url.openConnection();
            byte[] bytes;
            try (InputStream inputStream = urlConnection.getInputStream()) {
                bytes = getBytesFromStream(inputStream);
            }

            return new String(bytes);
        } catch (IOException e) {
            e.printStackTrace();
            return "<error>" + e.getMessage() + "</error>";
        }
    }

    public static byte[] downloadBytes(String user, String pwd, String server, String path) throws IOException {
        URL url = new URL("ftp://" + user + ":" + pwd + "@" + server + path);
        return buffer(url);
    }

    private static byte[] buffer(URL url) throws IOException {
        try (InputStream is = url.openStream()) {
            return getBytesFromStream(is);
        }
    }

    private static byte[] getBytesFromStream(InputStream is) throws IOException {
        try (ByteArrayOutputStream os =
                     new ByteArrayOutputStream() ) {

            int read;
            byte[] bytes = new byte[BUFFER_SIZE];

            while ((read = is.read(bytes)) != -1) {
                os.write(bytes, 0, read);
            }
            return os.toByteArray();
        }
    }

    public static String upload(String user, String pwd, String server, String path, String sourcePath) {
        try {
            URL url = new URL("ftp://" + user + ":" + pwd + "@" + server + path);
            URLConnection conn = url.openConnection();
            transmit(conn, sourcePath);
            return "<success>Uploaded " + sourcePath + " to " + "ftp://" + server + path + "</success>";
        } catch (IOException e) {
            e.printStackTrace();
            return "<error>" + e.getMessage() + "</error>";
        }
    }

    private static void transmit(URLConnection connection, String file) throws IOException {
        try (OutputStream os = connection.getOutputStream()) {
            try (FileInputStream is = new FileInputStream(file)) {

                byte[] buffer = new byte[BUFFER_SIZE];
                int bytesRead = -1;
                while ((bytesRead = is.read(buffer)) != -1) {
                    os.write(buffer, 0, bytesRead);
                }
            }
        }
    }

    public static String uploadBytes(String user, String pwd, String server, String path, byte[] byteArray) {
        try {
            URL url = new URL("ftp://" + user + ":" + pwd + "@" + server + path);
            URLConnection conn = url.openConnection();
            transmit(conn, byteArray);
            return "<success>Uploaded byte array to " + "ftp://" + server + path + "</success>";
        } catch (IOException e) {
            e.printStackTrace();
            return "<error>" + e.getMessage() + "</error>";
        }
    }

    private static void transmit(URLConnection connection, byte[] byteArray) throws IOException {
        try (OutputStream os = connection.getOutputStream()) {
            os.write(byteArray);
        }
    }
}
