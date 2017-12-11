# A fast SAX style JSON parser for Swift.

Many DOM style ways to parse JSON are available for Swift, notably the Swift 4 technique using the Codable protocol. All of them require you to have the complete JSON message before you can start parsing it. They then parse it (almost automatically) to a set of Swift objects and arrays which correspond directly to the objects and arrays in the JSON. The only deviations from this correspondence are that you can skip past unwanted members of JSON objects, and you can map JSON object member names to different Swift object member names.

Sometimes that isn't what's wanted. Maybe the JSON's coming from the network in a series of data chunks, and (for performance reasons) you'd like to parse each chunk immediately after it's arrived, instead of having to wait for all the chunks to arrive before starting to parse. Or maybe you'd like to transfer the data from the JSON directly into a database, without slowing things down by always instantiating intermediate Swift objects for every data item transferred.

This parser addresses those issues. It doesn't make any Swift objects for you, it just parses the JSON and tells you whats there. It can parse input in chunks, with no restrictions on whereabouts in the JSON the boundaries between chunks occur. Internally it keeps track of the parse state in between chunks, so when the next chunk comes in it automatically picks up from where it left off without you having to do anything to make this happen.

It parses JSON as defined at http://json.org with one addition. Like javascript itself, it permits single quotes (unicode 39) as well as double quotes (unicode 34) to be used as string delimiters.

To use it first make an instance of JsonUtf8PullParser.

Supply input by first calling startJson() to indicate the beginning of a series of chunks of JSON. Then deliver the first chunk by calling supplyInput(utf8Json : Data, floor : Int, roof : Int). It expects the JSON as UTF-8 in a byte buffer of type Foundation.Data, floor is the index of the first byte of JSON, and roof is the index of the byte after the last byte of JSON. After each chunk's been parsed, deliver the next chunk by calling supplyInput() again. Start a new series of chunks by calling startJson() again.

Get the data out by first calling nextEvent(). It returns a value from the JsonUtf8PullParser.Event enumeration which tells you what it's just parsed. It will be 1 of the following:

    START_JSON
    END_JSON
    START_ARRAY
    END_ARRAY
    START_OBJECT
    END_OBJECT
    START_NVP
    END_NVP
    NUMBER
    STRING
    TRUE
    FALSE
    NULL
    JSON_FORMAT_ERROR
    SUPPLY_MORE_INPUT

SUPPLY_MORE_INPUT means it's parsed all the way to the end of the current chunk. The parser is now ready to accept the next chunk (via supplyInput()).

START_NVP means it parsed the start of an object member. Call getString() to get the name of the object member. Its value is whatever comes between START_NVP and END_NVP.

STRING means it parsed a JSON string. Call getString() to get the string.

NUMBER means it parsed a JSON number. Call getString() to get the number as a string. Call getDouble(), getInt(), getUInt64(), etc. to get the number as a numeric type.

For example, the following code:

    // Get the JSON as UTF-8 in 2 Data objects, d1 and d2.

    let json =
        "{\n" +
        "\"people\":\n" +
        "    [\n" +
        "    { \"name\": [ \"Jane\", \"Doe\" ], \"year born\": 1990, \"veggi\": false },\n" +
        "    { \"name\": [ \"John\", \"Doe\" ], \"year born\": 1992, \"veggi\": true }\n" +
        "    ],\n" +
        "'zoo':\n" +
        "    {\n" +
        "    'name': \"Durell's Zoo\",\n" +
        "    'animals': [ 'cat', 'dog', 'lion', 'tiger', 'goldfish' ],\n" +
        "    'year founded': null\n" +
        "    }\n" +
        "}"
    print(json);
    print();
    var i = 0
    var d1 = Data()
    var d2 = Data()
    for c in json.utf8
        {
        if i < 36
            { d1.append(c) }
        else
            { d2.append(c) }
        i += 1
        }

    // Parse the JSON.

    let p = JsonUtf8PullParser()
    p.startJson()
    p.supplyInput(utf8Json: d1, floor: 0, roof: d1.count)
    var e = JsonUtf8PullParser.Event.NO_EVENT
    repeat
        {
        e = p.nextEvent()
        switch e
            {
            case JsonUtf8PullParser.Event.START_NVP:
                print("\(e.name) \(p.getString().characters.count) \(p.getString())")
                break
            case JsonUtf8PullParser.Event.NUMBER:
                print("\(e.name) \(p.getInt())")
                break
            case JsonUtf8PullParser.Event.STRING:
                print("\(e.name) \(p.getString().characters.count) \(p.getString())")
                break
            case JsonUtf8PullParser.Event.SUPPLY_MORE_INPUT:
                print(e.name); p.supplyInput(utf8Json: d2, floor: 0, roof: d2.count)
                break
            default:
                print(e.name)
                break
            }
        }
    while e != JsonUtf8PullParser.Event.END_JSON

Produces the following output:

    {
    "people":
        [
        { "name": [ "Jane", "Doe" ], "year born": 1990, "veggi": false },
        { "name": [ "John", "Doe" ], "year born": 1992, "veggi": true }
        ],
    'zoo':
        {
        'name': "Durell's Zoo",
        'animals': [ 'cat', 'dog', 'lion', 'tiger', 'goldfish' ],
        'year founded': null
        }
    }

    START_JSON
    START_OBJECT
    START_NVP 6 people
    START_ARRAY
    START_OBJECT
    START_NVP 4 name
    START_ARRAY
    SUPPLY_MORE_INPUT
    STRING 4 Jane
    STRING 3 Doe
    END_ARRAY
    END_NVP
    START_NVP 9 year born
    NUMBER 1990
    END_NVP
    START_NVP 5 veggi
    FALSE
    END_NVP
    END_OBJECT
    START_OBJECT
    START_NVP 4 name
    START_ARRAY
    STRING 4 John
    STRING 3 Doe
    END_ARRAY
    END_NVP
    START_NVP 9 year born
    NUMBER 1992
    END_NVP
    START_NVP 5 veggi
    TRUE
    END_NVP
    END_OBJECT
    END_ARRAY
    END_NVP
    START_NVP 3 zoo
    START_OBJECT
    START_NVP 4 name
    STRING 12 Durell's Zoo
    END_NVP
    START_NVP 7 animals
    START_ARRAY
    STRING 3 cat
    STRING 3 dog
    STRING 4 lion
    STRING 5 tiger
    STRING 8 goldfish
    END_ARRAY
    END_NVP
    START_NVP 12 year founded
    NULL
    END_NVP
    END_OBJECT
    END_NVP
    END_OBJECT
    END_JSON
