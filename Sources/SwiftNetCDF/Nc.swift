//
//  Nc.swift
//  SwiftNetCDF
//
//  Created by Patrick Zippenfenig on 2019-09-10.
//

import CNetCDF
import Foundation

/// All errors this library could throw
public enum NetCDFError: Error {
    case ncerror(code: Int32, error: String)
    case invalidVariable
    case noGroupFound
    case badNcid
    case badVarid
    case badGroupid
    case badName
    case alreadyInDefineMode
    case attributeNotFound
    case noPermissions
    case valueCanNotBeConverted
    case operationRequiresNetCDFv4
    case fileIsInStrictNetCDFv3Mode
    case numberOfDimensionsInvalid
    case numberOfElementsInvalid
    case tooManyOpenFiles
    case outOfMemory
    case hdf5Error
    case netCDF4MetedataError
    case alreadyExists
    
    init(ncerr: Int32) {
        switch ncerr {
        case NC_ENOTVAR: self = .invalidVariable
        case NC_EBADID: self = .badNcid
        case NC_ENOTVAR: self = .badVarid
        case NC_EBADGRPID: self = .badGroupid
        case NC_EBADNAME: self = .badName
        case NC_ENOTATT: self = .attributeNotFound
        case NC_EINDEFINE: self = .alreadyInDefineMode
        case NC_EPERM: self = .noPermissions
        case NC_ENOTNC4: self = .operationRequiresNetCDFv4
        case NC_ESTRICTNC3: self = .fileIsInStrictNetCDFv3Mode
        case NC_ENOGRP: self = .noGroupFound
        case NC_ENFILE: self = .tooManyOpenFiles
        case NC_ENOMEM: self = .outOfMemory
        case NC_EHDFERR: self = .hdf5Error
        case NC_EDIMMETA: self = .netCDF4MetedataError
        case NC_EEXIST: self = .alreadyExists
        default:
            let error = String(cString: nc_strerror(ncerr))
            self = .ncerror(code: ncerr, error: error)
        }
    }
}

public extension ExternalDataType {
    var typeId: TypeId {
        return TypeId(rawValue)
    }
}

/// Represent a data type ID. Could be an external or userdefined type.
public struct TypeId: Equatable {
    let typeid: Int32
    
    fileprivate init(_ typeid: Int32) {
        self.typeid = typeid
    }
}

/**
 A VarId is always bound to a NcId. We make sure this stays this way.
 */
public struct VarId {
    public let ncid: NcId
    let varid: Int32
    
    fileprivate init(ncid: NcId, varid: Int32) {
        self.ncid = ncid
        self.varid = varid
    }
    
    /// Get information about this variable
    public func inq_var() -> (name: String, type: TypeId, dimensionIds: [DimId], nAttributes: Int32) {
        let nDimensions = inq_varndims()
        var dimensionIds = [Int32](repeating: 0, count: Int(nDimensions))
        var nAttribudes: Int32 = 0
        var typeid: Int32 = 0
        /// Throws only on invalid IDs. Should not be possible
        let name = try! Nc.execWithStringBuffer {
            nc_inq_var(ncid.ncid, varid, $0, &typeid, nil, &dimensionIds, &nAttribudes)
        }
        return (name, TypeId(typeid), dimensionIds.map(DimId.init), nAttribudes)
    }
    
    /// Get the name of an attribute by id. Throws on internal netcdf stuff.
    public func inq_attname(attid: Int32) throws -> String {
        return try Nc.execWithStringBuffer {
            nc_inq_attname(ncid.ncid, varid, attid, $0)
        }
    }
    
    /// Get the type and length of an attribute. Throws on internal netcdf stuff.
    public func inq_att(name: String) throws -> (type: TypeId, length: Int) {
        var typeid: Int32 = 0
        var len: Int = 0
        try Nc.exec {
            nc_inq_att(ncid.ncid, varid, name, &typeid, &len)
        }
        return (TypeId(typeid), len)
    }
    
    /// Get all variable IDs of a group id
    public func inq_varndims() -> Int32 {
        var count: Int32 = 0
        /// Throws only on invalid IDs. Should not be possible
        try! Nc.exec {
            nc_inq_varndims(ncid.ncid, varid, &count)
        }
        return count
    }
    
    /// Set a new attribute
    public func put_att(name: String, type: TypeId, length: Int, ptr: UnsafeRawPointer) throws {
        try Nc.exec {
            nc_put_att(ncid.ncid, varid, name, type.typeid, length, ptr)
        }
    }
    
    /// Length of a attribute by name
    /*public func inq_attlen(name: String) throws -> Int {
        var len: Int = 0
        try Nc.exec {
            nc_inq_attlen(ncid.ncid, varid, name, &len)
        }
        return len
    }*/
    
    /// Number of attributes in this variable
    public func inq_varnatts() -> Int32 {
        var count: Int32 = 0
        /// This can only throw on invalid ncid or varid. Should not be possible.
        try! Nc.exec {
            nc_inq_varnatts(ncid.ncid, varid, &count)
        }
        return count
    }
    
    /// Read an attribute into a buffer
    public func get_att(name: String, buffer: UnsafeMutableRawPointer) throws {
        try Nc.exec {
            nc_get_att(ncid.ncid, varid, name, buffer)
        }
    }
    
    /// Read the variable by offset and count vector into a buffer
    public func get_vara(offset: [Int], count: [Int], buffer: UnsafeMutableRawPointer) throws {
        try Nc.exec {
            nc_get_vara(ncid.ncid, varid, offset, count, buffer)
        }
    }
    
    /// Read the variable by offset, count and stride vector into a buffer
    public func get_vars(offset: [Int], count: [Int], stride: [Int], buffer: UnsafeMutableRawPointer) throws {
        try Nc.exec {
            nc_get_vars(ncid.ncid, varid, offset, count, stride, buffer)
        }
    }
    
    /// Write a buffer by offset and count into this variable
    public func put_vara(offset: [Int], count: [Int], ptr: UnsafeRawPointer) throws {
        try Nc.exec {
            nc_put_vara(ncid.ncid, varid, offset, count, ptr)
        }
    }
    
    /// Write a buffer by offset, count and stride into this variable
    public func put_vars(offset: [Int], count: [Int], stride: [Int], ptr: UnsafeRawPointer) throws {
        try Nc.exec {
            nc_put_vars(ncid.ncid, varid, offset, count, stride, ptr)
        }
    }
    
    /// Set deflate options
    public func def_var_deflate(shuffle: Bool, deflate: Bool, deflate_level: Int32) throws {
        try Nc.exec {
            nc_def_var_deflate(ncid.ncid, varid, shuffle ? 1 : 0, deflate ? 1 : 0, deflate_level)
        }
    }
    
    /// Options for chunking
    public enum Chunking {
        case chunked
        case contingous
        
        fileprivate var netcdfValue: Int32 {
            switch self {
            case .chunked: return NC_CHUNKED
            case .contingous: return NC_CONTIGUOUS
            }
        }
    }
    
    /// Set chunking options
    public func def_var_chunking(type: Chunking, chunks: [Int]) throws {
        try Nc.exec {
            return nc_def_var_chunking(ncid.ncid, varid, type.netcdfValue, chunks)
        }
    }
    
    /// Set flecther32 options
    public func def_var_flechter32(enable: Bool) throws {
        try Nc.exec {
            nc_def_var_fletcher32(ncid.ncid, varid, enable ? 1 : 0)
        }
    }
    
    /// Options for endian
    public enum Endian {
        case native
        case little
        case big
        
        fileprivate var netcdfValue: Int32 {
            switch self {
            case .native: return NC_ENDIAN_NATIVE
            case .little: return NC_ENDIAN_LITTLE
            case .big: return NC_ENDIAN_BIG
            }
        }
    }
    
    /// Set endian options
    public func def_var_endian(type: Endian) throws {
        try Nc.exec {
            nc_def_var_endian(ncid.ncid, varid, type.netcdfValue)
        }
    }
    
    /// Set filter options
    public func def_var_filter(id: UInt32, params: [UInt32]) throws {
        try Nc.exec {
            nc_def_var_filter(ncid.ncid, varid, id, params.count, params)
        }
    }
}


/// Represent a dimension id.
public struct DimId: Equatable {
    let dimid: Int32
    
    fileprivate init(_ dimid: Int32) {
        self.dimid = dimid
    }
    
    /// A dimension could be of fixed or unlimited length
    public enum Length {
        case unlimited
        case length(Int)
        
        var netCdfValue: Int {
            switch self {
            case .unlimited: return NC_UNLIMITED
            case .length(let length): return length
            }
        }
    }
}

/**
 A ncid might be a file or a group handle.
 */
public struct NcId {
    let ncid: Int32
    
    fileprivate init(_ ncid: Int32) {
        self.ncid = ncid
    }
    
    /**
     A global var is used for global attributes on ncid
     */
    func NC_GLOBAL() -> VarId {
        return VarId(ncid: self, varid: CNetCDF.NC_GLOBAL)
    }
    
    /// Get information on a type. Works for external and user types
    public func inq_type(type: TypeId) throws -> (name: String, size: Int) {
        var size = 0
        let name = try Nc.execWithStringBuffer {
            nc_inq_type(ncid, type.typeid, $0, &size)
        }
        return (name, size)
    }
    
    /// Get information on user types. Does not work for external types
    public func inq_user_type(type: TypeId) throws -> (name: String, size: Int, baseType: TypeId, numberOfFields: Int, classType: Int32) {
        var size = 0
        var baseTypeId: Int32 = 0
        var numberOfFields = 0
        var classType: Int32 = 0
        let name = try Nc.execWithStringBuffer {
            nc_inq_user_type(ncid, type.typeid, $0, &size, &baseTypeId, &numberOfFields, &classType)
        }
        return (name, size, TypeId(baseTypeId), numberOfFields, classType)
    }
    
    /// Sync to disk
    public func sync() {
        /// Throws only for wrong ncid. Should not be possible.
        try! Nc.exec {
            nc_sync(ncid)
        }
    }
    
    /**
     Close the netcdf file.
     
     - Throws `NetCDFError.badGroupid` if this was not the root id.
     */
    public func close() throws {
        try Nc.exec {
            nc_close(ncid)
        }
    }
    
    /// Set to define mode
    public func redef() throws {
        try Nc.exec {
            nc_redef(ncid)
        }
    }
    
    /// Set to define mode
    public func enddef() {
        /// Throws only for wrong ncid. Should not be possible.
        try! Nc.exec {
            nc_enddef(ncid)
        }
    }
    
    /// Fill mode for set_fill
    public enum FillMode {
        case fill
        case noFill
        
        var netCdfValue: Int32 {
            switch self {
            case .fill: return NC_FILL
            case .noFill: return NC_NOFILL
            }
        }
    }
    
    /// Set the fill mode
    public func set_fill(mode: FillMode) throws {
        try Nc.exec {
            nc_set_fill(ncid, mode.netCdfValue, nil)
        }
    }
    
    
    /// Numer of attributes for this ncid
    public func inq_natts() -> Int32 {
        var count: Int32 = 0
        /// Throws only for wrong ncid. Should not be possible.
        try! Nc.exec {
            nc_inq_natts(ncid, &count)
        }
        return count
    }
    
    /// Get all variable IDs of a group id
    public func inq_varids() -> [VarId] {
        var count: Int32 = 0
        /// No documented throw
        try! Nc.exec {
            nc_inq_varids(ncid, &count, nil)
        }
        var ids = [Int32](repeating: 0, count: Int(count))
        try! Nc.exec {
            nc_inq_varids(ncid, nil, &ids)
        }
        return ids.map { VarId(ncid: self, varid: $0) }
    }
    
    /// Get the name of this group
    public func inq_grpname() -> String {
        var nameLength = 0
        /// No documented throw
        try! Nc.exec {
            nc_inq_grpname_len(ncid, &nameLength)
        }
        var nameBuffer = [Int8](repeating: 0, count: nameLength) // CHECK +1 needed?
        try! Nc.exec {
            nc_inq_grpname(ncid, &nameBuffer)
        }
        return String(cString: nameBuffer)
    }
    
    /// Define a new sub group
    public func def_grp(name: String) throws -> NcId {
        var newNcid: Int32 = 0
        try Nc.exec {
            nc_def_grp(ncid, name, &newNcid)
        }
        return NcId(newNcid)
    }
    
    /// Get a variable by name
    /// - Throws: `NetCDFError.invalidVariable` if variable does not exist
    public func inq_varid(name: String) -> VarId? {
        do {
            var id: Int32 = 0
            try Nc.exec { nc_inq_varid(ncid, name, &id) }
            return VarId(ncid: self, varid: id)
        } catch (NetCDFError.invalidVariable) {
            return nil
        } catch {
            fatalError("There should ne not other reaachable errors")
        }
    }
    
    /// Get all sub group IDs
    public func inq_grps() -> [NcId] {
        var count: Int32 = 0
        // No documented errors possible
        try! Nc.exec {
            nc_inq_grps(ncid, &count, nil)
        }
        var ids = [Int32](repeating: 0, count: Int(count))
        try! Nc.exec {
            nc_inq_grps(ncid, nil, &ids)
        }
        return ids.map(NcId.init)
    }
    
    /// Get a group by name. Nil if group was not found
    public func inq_grp_ncid(name: String) -> NcId? {
        do {
            var id: Int32 = 0
            try Nc.exec { nc_inq_grp_ncid(ncid, name, &id) }
            return NcId(id)
        } catch (NetCDFError.noGroupFound) {
            return nil
        } catch {
            fatalError("There should ne not other reaachable errors")
        }
    }
    
    /**
     Get a list of IDs of unlimited dimensions.
     In netCDF-4 files, it's possible to have multiple unlimited dimensions. This function returns a list of the unlimited dimension ids visible in a group.
     Dimensions are visible in a group if they have been defined in that group, or any ancestor group.
     
     - Throws: if not in NetCDF-4 mode
     */
    public func inq_unlimdims() throws -> [DimId] {
        // Get the number of dimensions
        var count: Int32 = 0
        try Nc.exec {
            nc_inq_unlimdims(ncid, &count, nil)
        }
        // Allocate array and get the IDs
        var dimensions = [Int32](repeating: 0, count: Int(count))
        try Nc.exec {
            nc_inq_unlimdims(ncid, nil, &dimensions)
        }
        return dimensions.map(DimId.init)
    }

    /// List all Dimension ids of this ncid
    public func inq_dimids(includeParents: Bool) -> [DimId] {
        // Get the number of dimensions
        var count: Int32 = 0
        try! Nc.exec {
            /// no documented error should possible
            nc_inq_dimids(ncid, &count, nil, includeParents ? 1 : 0)
        }
        // Allocate array and get the IDs
        var ids = [Int32](repeating: 0, count: Int(count))
        try! Nc.exec {
            /// no documented error should possible
            nc_inq_dimids(ncid, nil, &ids, includeParents ? 1 : 0)
        }
        return ids.map(DimId.init)
    }
    
    /// Get name and length of a dimension
    public func inq_dim(dimid: DimId) -> (name: String, length: Int) {
        var len: Int = 0
        /// Throws only on invalid IDs. Should not be possible
        let name = try! Nc.execWithStringBuffer {
            nc_inq_dim(ncid, dimid.dimid, $0, &len)
        }
        return (name, len)
    }
    
    /// Define a new dimension
    public func def_dim(name: String, length: DimId.Length) throws -> DimId {
        var dimid: Int32 = 0
        try Nc.exec {
            nc_def_dim(ncid, name, length.netCdfValue, &dimid)
        }
        return DimId(dimid)
    }
    
    /// Define a new variable
    public func def_var( name: String, type: TypeId, dimensionIds: [DimId]) throws -> VarId {
        var varid: Int32 = 0
        try Nc.exec {
            nc_def_var(ncid, name, type.typeid, Int32(dimensionIds.count), dimensionIds.map{$0.dimid}, &varid)
        }
        return VarId(ncid: self, varid: varid)
    }
}



/**
 This struct wraps NetCDF C library functions to a more safe Swift syntax.
 A lock is used to ensure the library is not acessed from multiple threads simultaniously.
 */
public struct Nc {
    /**
     A Lock to serialise access to the NetCDF C library.
     */
    private static let lock = Lock()
    
    /**
     Reused buffer which some NetCDF routines can write names into. Afterwards it should be converted to a Swift String.
     The buffer should only be used with a thread lock.
     */
    private static var maxNameBuffer = [Int8](repeating: 0, count: Int(NC_MAX_NAME+1))
    
    /**
     Execute a netcdf command in a thread safe lock and check the error code. Throw an exception otherwise.
     */
    fileprivate static func exec(_ fn: () -> Int32) throws {
        let ncerr = Nc.lock.withLock(fn)
        guard ncerr == NC_NOERR else {
            throw NetCDFError(ncerr: ncerr)
        }
    }
    
    /**
     Execute a closure which takes a buffer for a netcdf variable NC_MAX_NAME const string.
     Afterwards the buffer is converted to a Swift string
     */
    fileprivate static func execWithStringBuffer(_ fn: (UnsafeMutablePointer<Int8>) -> Int32) throws -> String {
        return try Nc.lock.withLock {
            let error = fn(&Nc.maxNameBuffer)
            guard error == NC_NOERR else {
                throw NetCDFError(ncerr: error)
            }
            return String(cString: &Nc.maxNameBuffer)
        }
    }
}

public extension Nc {
    /**
     NetCDF library version string like: "4.6.3 of May  8 2019 00:09:03 $"
     */
    static func inq_libvers() -> String {
        return Nc.lock.withLock {
            String(cString: nc_inq_libvers())
        }
    }
    
    /// Open an exsiting NetCDF file
    static func open(path: String, omode: Int32) throws -> NcId {
        var ncid: Int32 = 0
        try exec {
            nc_open(path, omode, &ncid)
        }
        return NcId(ncid)
    }
    
    /// Open an exsiting NetCDF file
    static func open(path: String, allowWrite: Bool) throws -> NcId {
        return try open(path: path, omode: allowWrite ? NC_WRITE : 0)
    }
    
    /// Create a new NetCDF file
    static func create(path: String, cmode: Int32) throws -> NcId {
        var ncid: Int32 = 0
        try exec {
            nc_create(path, cmode, &ncid)
        }
        return NcId(ncid)
    }
    
    /// Create a new NetCDF file
    static func create(path: String, overwriteExisting: Bool, useNetCDF4: Bool) throws -> NcId {
        var cmode = Int32(0)
        if overwriteExisting == false {
            cmode |= NC_NOCLOBBER
        }
        if useNetCDF4 {
            cmode |= NC_NETCDF4
        }
        return try create(path: path, cmode: cmode)
    }
    
    /// Free memory for returned string arrays
    static func free_string(len: Int, stringArray: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>) {
        /// no error should be possible
        try! exec {
            nc_free_string(len, stringArray)
        }
    }
}
