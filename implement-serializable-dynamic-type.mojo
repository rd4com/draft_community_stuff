# just for fun/inspiration/example/discussion, 
# not tested and probably have many bugs!
def main():
    var tmp = DynamicObjects()
    
    var obj = DynamicObject()
    obj.set("some uint8",UInt8(255))
    obj.set("some field name", "some value")
    tmp.add(obj)
    
    var obj2 = DynamicObject()
    obj2.set[Float32]("some float32",1.5)
    tmp.add(obj2)

    var tmpobj = tmp[1]
    tmpobj.set[Float32]("some float32",3.5)
    tmp[1] = tmpobj #update

    #serialize into DynamicVector[UInt8] :
    var objects_serialized = DynamicObjects.Serialize(tmp)  

    #deserialize into DynamicObjects :
    var objects_deserialized = DynamicObjects.Deserialize(objects_serialized)

    print(objects_deserialized[0].get[UInt8]("some uint8"))
    print(objects_deserialized[0].get("some field name"))
    print(objects_deserialized[1].get[Float32]("some float32"))

@value
struct Field(CollectionElement):
    var name: String
    var data:DynamicVector[UInt8]
    fn __init__(inout self,name:String):
        self.name=name
        self.data=DynamicVector[UInt8]()
        
@value
struct DynamicObject(CollectionElement):
    #id
    var fields:DynamicVector[Field]
    fn __init__(inout self): self.fields=DynamicVector[Field]()
    
    fn set[T:AnyRegType](inout self,k:String, value:T):
        var v = value
        let ptr = Pointer.address_of(v).bitcast[UInt8]()
        for f in range(len(self.fields)):
            if self.fields[f].name == k:
                self.fields[f].data = DynamicVector[UInt8]()
                for i in range(sizeof[T]()):
                    self.fields[f].data.push_back(ptr[i])
                return
        var tmp = Field(k)
        for i in range(sizeof[T]()):
            tmp.data.push_back(ptr[i])
        self.fields.push_back(tmp)

    fn set(inout self,k:String,value:StringLiteral):self.set(k,String(value))
    fn set(inout self,k:String,value:String):
        for f in range(len(self.fields)):
            if self.fields[f].name == k:
                self.fields[f].data = DynamicVector[UInt8]()
                var p = DynamicVector[UInt8]()
                for i in range(len(value)): p.push_back(ord(value[i]))
                p.push_back(0)
                self.fields[f].data = p^
                return
        var tmp = Field(k)
        for i in range(len(value)): tmp.data.push_back(ord(value[i]))
        tmp.data.push_back(0)
        self.fields.push_back(tmp)
    
    fn get[T:AnyRegType](inout self,k:String) raises ->T:
        for f in range(len(self.fields)):
            if self.fields[f].name == k:
                if len(self.fields[f].data)==0:
                    raise Error("empty value")
                let p = Pointer[T].alloc(sizeof[T]())
                let p_bitcast = p.bitcast[UInt8]()
                for i in range(sizeof[T]()):
                    p_bitcast[i]=self.fields[f].data[i]
                let val:T = p[0]
                p.free()
                return val
        raise Error("not found")

    fn get(inout self,k:String) raises ->String:
        for f in range(len(self.fields)):
            if self.fields[f].name == k:
                if len(self.fields[f].data)==0:
                    raise Error("empty value")
                var tmp = DynamicVector[Int8]()
                for i in range(len(self.fields[f].data)): 
                    tmp.push_back(self.fields[f].data[i].cast[DType.int8]())
                
                return String(tmp^)
        raise Error("not found")

@value
struct DynamicObjects(Sized):  
    var objects: DynamicVector[DynamicObject]
    fn __init__(inout self):
        self.objects = DynamicVector[DynamicObject]()
    fn add(inout self,inout o: DynamicObject):
        self.objects.push_back(o)
    fn __getitem__(self,index:Int) raises -> DynamicObject:
        if index>=len(self): raise Error("bound check failed")
        return self.objects[index]
    fn __setitem__(inout self, index:Int,o:DynamicObject) raises:
        if index>=len(self): raise Error("bound check failed")
        self.objects[index]=o
    fn __len__(self)->Int: return len(self.objects)
    

    @staticmethod
    fn write_int(inout vec:DynamicVector[UInt8],i:Int):
        var v = i
        let ptr = Pointer[Int].address_of(v).bitcast[UInt8]()
        for i in range(sizeof[Int]()):
            vec.push_back(ptr[i])
        
    
    @staticmethod
    fn read_int(vec: DynamicVector[UInt8],inout offset:Int)->Int:
        var result:Int = 0
        let ptr = Pointer[Int].address_of(result).bitcast[UInt8]()
        for i in range(sizeof[Int]()):
            ptr[i]=vec[i+offset]
        offset +=sizeof[Int]()
        return result
    
    @staticmethod
    fn Serialize(arg: DynamicObjects)->DynamicVector[UInt8]:
        var data = DynamicVector[UInt8]()
        Self.write_int(data,len(arg.objects))
        for o in range(len(arg.objects)):
            let obj = arg.objects[o]
            Self.write_int(data,len(obj.fields))
            for f in range(len(obj.fields)):
                Self.write_int(data,len(obj.fields[f].name)+1)
                Self.write_int(data,len(obj.fields[f].data))
                for b in range(len(obj.fields[f].name)):
                    data.push_back(ord(obj.fields[f].name[b]))
                data.push_back(0)
                for b in range(len(obj.fields[f].data)):
                    data.push_back(obj.fields[f].data[b])
        return data
    
    @staticmethod
    fn Deserialize(data: DynamicVector[UInt8])->Self:
        var res = Self()
        var offset = 0
        let objects = Self.read_int(data,offset)
        
        for o in range(objects):
            var tmp = DynamicObject()
            let fields = Self.read_int(data,offset)
            
            for f in range(fields):
                let fieldnamesize = Self.read_int(data,offset)
                let fieldsize = Self.read_int(data,offset)
                var name = DynamicVector[SIMD[DType.int8, 1]]()
                for i in range(fieldnamesize):
                    name.push_back(data[offset+i].cast[DType.int8]())
                var tmp2 = Field(String(name^))
                offset+=fieldnamesize
                var data2 = DynamicVector[UInt8]()
                for i in range(fieldsize):
                    data2.push_back(data[offset+i])
                tmp2.data=data2^
                offset+=fieldsize
                tmp.fields.push_back(tmp2^)
            res.objects.push_back(tmp^)
        
        return res^
 