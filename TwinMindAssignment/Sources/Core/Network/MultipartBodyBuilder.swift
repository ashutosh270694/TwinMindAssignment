import Foundation

/// Minimal utility for building multipart/form-data request bodies
struct MultipartBodyBuilder {
    
    // MARK: - Properties
    
    private let boundary: String
    private var bodyData = Data()
    
    // MARK: - Initialization
    
    init() {
        // Generate a unique boundary string
        self.boundary = "Boundary-\(UUID().uuidString)"
    }
    
    // MARK: - Public Methods
    
    /// Adds a text field to the multipart body
    /// - Parameters:
    ///   - name: Field name
    ///   - value: Field value
    mutating func addTextField(name: String, value: String) {
        let fieldData = createTextFieldData(name: name, value: value)
        bodyData.append(fieldData)
    }
    
    /// Adds a file field to the multipart body
    /// - Parameters:
    ///   - name: Field name
    ///   - filename: Name of the file
    ///   - mimeType: MIME type of the file
    ///   - fileData: File data
    mutating func addFileField(name: String, filename: String, mimeType: String, fileData: Data) {
        let fieldData = createFileFieldData(name: name, filename: filename, mimeType: mimeType, fileData: fileData)
        bodyData.append(fieldData)
    }
    
    /// Finalizes the multipart body and returns the complete data
    /// - Returns: Complete multipart body data
    mutating func finalize() -> Data {
        let closingBoundary = "\r\n--\(boundary)--\r\n"
        bodyData.append(Data(closingBoundary.utf8))
        return bodyData
    }
    
    /// Returns the boundary string for the Content-Type header
    var boundaryString: String {
        return boundary
    }
    
    // MARK: - Private Methods
    
    private func createTextFieldData(name: String, value: String) -> Data {
        var fieldData = Data()
        
        // Add boundary
        fieldData.append(Data("--\(boundary)\r\n".utf8))
        
        // Add content disposition header
        let disposition = "Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n"
        fieldData.append(Data(disposition.utf8))
        
        // Add field value
        fieldData.append(Data(value.utf8))
        fieldData.append(Data("\r\n".utf8))
        
        return fieldData
    }
    
    private func createFileFieldData(name: String, filename: String, mimeType: String, fileData: Data) -> Data {
        var fieldData = Data()
        
        // Add boundary
        fieldData.append(Data("--\(boundary)\r\n".utf8))
        
        // Add content disposition header
        let disposition = "Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n"
        fieldData.append(Data(disposition.utf8))
        
        // Add content type header
        let contentType = "Content-Type: \(mimeType)\r\n\r\n"
        fieldData.append(Data(contentType.utf8))
        
        // Add file data
        fieldData.append(fileData)
        fieldData.append(Data("\r\n".utf8))
        
        return fieldData
    }
}

// MARK: - Convenience Extensions

extension MultipartBodyBuilder {
    
    /// Creates a multipart body with a single file
    /// - Parameters:
    ///   - fileURL: URL of the file to upload
    ///   - fieldName: Name of the file field
    ///   - mimeType: MIME type of the file
    /// - Returns: Multipart body data and boundary string
    static func createFileUploadBody(
        fileURL: URL,
        fieldName: String,
        mimeType: String
    ) throws -> (data: Data, boundary: String) {
        let fileData = try Data(contentsOf: fileURL)
        let filename = fileURL.lastPathComponent
        
        var builder = MultipartBodyBuilder()
        builder.addFileField(name: fieldName, filename: filename, mimeType: mimeType, fileData: fileData)
        
        let bodyData = builder.finalize()
        return (bodyData, builder.boundaryString)
    }
    
    /// Creates a multipart body with a file and additional text fields
    /// - Parameters:
    ///   - fileURL: URL of the file to upload
    ///   - fieldName: Name of the file field
    ///   - mimeType: MIME type of the file
    ///   - textFields: Dictionary of text field names and values
    /// - Returns: Multipart body data and boundary string
    static func createFileUploadBody(
        fileURL: URL,
        fieldName: String,
        mimeType: String,
        textFields: [String: String]
    ) throws -> (data: Data, boundary: String) {
        let fileData = try Data(contentsOf: fileURL)
        let filename = fileURL.lastPathComponent
        
        var builder = MultipartBodyBuilder()
        
        // Add text fields first
        for (name, value) in textFields {
            builder.addTextField(name: name, value: value)
        }
        
        // Add file field
        builder.addFileField(name: fieldName, filename: filename, mimeType: mimeType, fileData: fileData)
        
        let bodyData = builder.finalize()
        return (bodyData, builder.boundaryString)
    }
} 