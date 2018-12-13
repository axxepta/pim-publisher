package de.axxepta.syncrovet.conversion;

import de.axxepta.syncrovet.ftp.FTPWrapper;
import org.apache.pdfbox.multipdf.PDFMergerUtility;
import org.apache.pdfbox.pdmodel.PDDocument;

import java.io.ByteArrayOutputStream;
import java.io.IOException;


public class PDF {

    public static String mergeRemotePDFs(String user, String pwd, String server, String sources, String target) {
        String[] inputFiles = nlListToArray(sources);
        PDFMergerUtility mergerUtility = new PDFMergerUtility();
        StringBuilder builder = new StringBuilder("<ftpPdfMerge>");
        try (PDDocument firstDoc = PDDocument.load(FTPWrapper.downloadBytes(user, pwd, server, inputFiles[0]))) {
            builder.append("<source>").append(inputFiles[0]).append("</source>");
            if (firstDoc.getEncryption() != null)
            {
                firstDoc.setAllSecurityToBeRemoved(true);
            }
            for (int i = 1; i < inputFiles.length; i++) {
                try (PDDocument appDocument = PDDocument.load(FTPWrapper.downloadBytes(user, pwd, server, inputFiles[i]))) {
                    appDocument.setAllSecurityToBeRemoved(true);
                    mergerUtility.appendDocument(firstDoc, appDocument);
                    builder.append("<source>").append(inputFiles[i]).append("</source>");
                } catch (IOException ex) {
                    ex.printStackTrace();
                    builder.append("<error>").append(ex.getMessage()).append("</error>");
                }
            }
            try (ByteArrayOutputStream os = new ByteArrayOutputStream()) {
                firstDoc.save(os);
                FTPWrapper.uploadBytes(user, pwd, server, target, os.toByteArray());
            }
        } catch (IOException e) {
            e.printStackTrace();
            builder.append("<error>").append(e.getMessage()).append("</error>");
        }
        builder.append("</ftpPdfMerge>");
        return builder.toString();
    }


    private static String[] nlListToArray(String nlList) {
        return nlList.split("\\r?\\n");
    }
}
