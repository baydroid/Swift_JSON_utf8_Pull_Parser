/*
 * Copyright 2017 transmission.aquitaine@yahoo.com
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Foundation



fileprivate let UNSET_DATA = Data()

fileprivate let CH_SPACE          : UInt8 = 32
fileprivate let CH_PLUS           : UInt8 = 43
fileprivate let CH_MINUS          : UInt8 = 45
fileprivate let CH_0              : UInt8 = 48
fileprivate let CH_9              : UInt8 = 57
fileprivate let CH_E              : UInt8 = 69
fileprivate let CH_e              : UInt8 = 101
fileprivate let CH_DOT            : UInt8 = 46
fileprivate let CH_OPEN_SQUARE    : UInt8 = 91
fileprivate let CH_OPEN_BRACE     : UInt8 = 123
fileprivate let CH_CLOSE_SQUARE   : UInt8 = 93
fileprivate let CH_CLOSE_BRACE    : UInt8 = 125
fileprivate let CH_COMMA          : UInt8 = 44
fileprivate let CH_COLON          : UInt8 = 58
fileprivate let CH_FORWARD_SLASH  : UInt8 = 47
fileprivate let CH_BACKWARD_SLASH : UInt8 = 92
fileprivate let CH_QUOTES         : UInt8 = 34
fileprivate let CH_APOSTROPHE     : UInt8 = 39
fileprivate let CH_b              : UInt8 = 98
fileprivate let CH_f              : UInt8 = 102
fileprivate let CH_n              : UInt8 = 110
fileprivate let CH_r              : UInt8 = 114
fileprivate let CH_t              : UInt8 = 116
fileprivate let CH_u              : UInt8 = 117
fileprivate let CH_l              : UInt8 = 108
fileprivate let CH_a              : UInt8 = 97
fileprivate let CH_s              : UInt8 = 115
fileprivate let CH_BS             : UInt8 = 8
fileprivate let CH_FF             : UInt8 = 12
fileprivate let CH_LF             : UInt8 = 10
fileprivate let CH_CR             : UInt8 = 13
fileprivate let CH_HT             : UInt8 = 9
fileprivate let CH_A              : UInt8 = 65



public class JsonUtf8PullParser
    {
    fileprivate var cc : UInt8 = 0                 // The byte of UTF-8 JSON currently being parsed
    fileprivate var jsonTextIndex = 0              // Index in jsonText of the next byte of UTF-8 JSON to be parsed
    fileprivate var jsonTextIndexRoof = 0          // Index in jsonText of the byte after the last byte of JSON in jsonText
    fileprivate var jsonText = UNSET_DATA          // JSON being parsed in UTF-8
    fileprivate var jStateIndex = 0                // Index of top of stack in jStates
    fileprivate var jStates = [JsonState.ROOT]     // JSON structure (array, object, object member name and value) parse state stack.
    fileprivate var dState = DataState.NOT_IN_DATA // Data primative (string, number, boolean, null) parse state.
    fileprivate var quoteCh = CH_QUOTES            // Terminating quote of the string being parsed
    fileprivate var buffer = Data()                // UTF-8 buffer for the data primative (string, number, boolean, null) being parsed
    fileprivate var hex = 0                        // Int buffer for the unicode string escape \u
    fileprivate var starting = true                // Flag indicating the start of a new JSON message
    fileprivate var done = false                   // Flag indicating the parser has reached the end of a JSON message

    public enum Event : Int
        {
        case SUPPLY_MORE_INPUT
        case START_JSON
        case START_ARRAY
        case START_OBJECT
        case END_ARRAY
        case END_OBJECT
        case END_NVP
        case START_NVP
        case NUMBER
        case STRING
        case TRUE
        case FALSE
        case NULL
        case END_JSON
        case JSON_FORMAT_ERROR
        case NO_EVENT

        public var name : String
            {
            get
                {
                switch self
                    {
                    case .SUPPLY_MORE_INPUT: return "SUPPLY_MORE_INPUT"
                    case .START_JSON:        return "START_JSON"
                    case .START_ARRAY:       return "START_ARRAY"
                    case .START_OBJECT:      return "START_OBJECT"
                    case .END_ARRAY:         return "END_ARRAY"
                    case .END_OBJECT:        return "END_OBJECT"
                    case .END_NVP:           return "END_NVP"
                    case .START_NVP:         return "START_NVP"
                    case .NUMBER:            return "NUMBER"
                    case .STRING:            return "STRING"
                    case .TRUE:              return "TRUE"
                    case .FALSE:             return "FALSE"
                    case .NULL:              return "NULL"
                    case .END_JSON:          return "END_JSON"
                    case .JSON_FORMAT_ERROR: return "JSON_FORMAT_ERROR"
                    case .NO_EVENT:          return "NO_EVENT"
                    }
                }
            }
        }

    fileprivate enum DataState : Int
        {
        case NOT_IN_DATA
        case NUMBER
        case STRING
        case ESCAPE
        case HEX0
        case HEX1
        case HEX2
        case HEX3
        }

    fileprivate enum JsonState : Int
        {
        case ROOT
        case ARRAY
        case OBJECT
        case OBJECT_NAME
        case OBJECT_VALUE
        }

    public func startJson()
        {
        starting = true
        done = false
        jStateIndex = 0
        jStates[0] = JsonState.ROOT
        dState = DataState.NOT_IN_DATA
        }

    public func supplyInput(utf8Json : Data, floor : Int, roof : Int)
        {
        jsonTextIndex = floor
        jsonTextIndexRoof = roof
        jsonText = utf8Json
        }

    public func nextEvent() -> JsonUtf8PullParser.Event
        {
        if starting
            {
            starting = false
            return Event.START_JSON
            }
        var e = Event.NO_EVENT
        repeat
            {
            switch dState
                {
                case DataState.NUMBER:               e = parseNumber();                                        break
                case DataState.STRING:               e = parseString();                                        break
                case DataState.ESCAPE:               e = parseEscape();                                        break
                case DataState.HEX0:                 e = parseHexDigit(shift: 12, nextDState: DataState.HEX1); break
                case DataState.HEX1:                 e = parseHexDigit(shift:  8, nextDState: DataState.HEX2); break
                case DataState.HEX2:                 e = parseHexDigit(shift:  4, nextDState: DataState.HEX3); break
                case DataState.HEX3:                 e = parseFinalHexDigit();                                 break
                case DataState.NOT_IN_DATA:
                    switch jState
                        {
                        case JsonState.ROOT:         e = parseRoot();                                          break
                        case JsonState.ARRAY:        e = parseArray();                                         break
                        case JsonState.OBJECT:       e = parseObject();                                        break
                        case JsonState.OBJECT_NAME:  e = parseObjectName();                                    break
                        case JsonState.OBJECT_VALUE: e = parseObjectValue();                                   break
                        }
                    break
                }
            }
        while e == Event.NO_EVENT
        return e
        }

    public func getData() -> Data
        {
        return buffer
        }

    public func getString() -> String
        {
        return String(data: buffer, encoding: String.Encoding.utf8)!
        }
    
    public func getDouble() -> Double
        {
        return Double(getString())!
        }

    public func getDoubleOpt() -> Double?
        {
        return Double(getString())
        }

    public func getInt() -> Int
        {
        return Int(getString())!
        }

    public func getIntOpt() -> Int?
        {
        return Int(getString())
        }

    public func getUInt() -> UInt
        {
        return UInt(getString())!
        }

    public func getUIntOpt() -> UInt?
        {
        return UInt(getString())
        }

    public func getInt64() -> Int64
        {
        return Int64(getString())!
        }

    public func getInt64Opt() -> Int64?
        {
        return Int64(getString())
        }

    public func getUInt64() -> UInt64
        {
        return UInt64(getString())!
        }

    public func getUInt64Opt() -> UInt64?
        {
        return UInt64(getString())
        }

    public func getInt32() -> Int32
        {
        return Int32(getString())!
        }

    public func getInt32Opt() -> Int32?
        {
        return Int32(getString())
        }

    public func getUInt32() -> UInt32
        {
        return UInt32(getString())!
        }

    public func getUInt32Opt() -> UInt32?
        {
        return UInt32(getString())
        }

    fileprivate func parseNumber() -> Event
        {
        if !nextCh() { return Event.SUPPLY_MORE_INPUT }
        if isNumericTerminator(cc)
            {
            backup1Char()
            dState = DataState.NOT_IN_DATA
            switch buffer.count
                {
                case 4:
                    if buffer[0] == CH_t && buffer[1] == CH_r && buffer[2] == CH_u && buffer[3] == CH_e { return Event.TRUE }
                    if buffer[0] == CH_n && buffer[1] == CH_u && buffer[2] == CH_l && buffer[3] == CH_l { return Event.NULL }
                    break
                case 5:
                    if buffer[0] == CH_f && buffer[1] == CH_a && buffer[2] == CH_l && buffer[3] == CH_s && buffer[4] == CH_e { return Event.FALSE }
                    break
                default:
                    break
                }
            return Event.NUMBER
            }
        else
            {
            buffer.append(cc)
            return Event.NO_EVENT
            }
        }

    fileprivate func parseString() -> Event
        {
        if !nextCh() { return Event.SUPPLY_MORE_INPUT }
        switch cc
            {
            case quoteCh:
                dState = DataState.NOT_IN_DATA
                return jState == JsonState.OBJECT_NAME ? Event.START_NVP : Event.STRING
            case CH_BACKWARD_SLASH:
                dState = DataState.ESCAPE
                break
            default:
                buffer.append(cc)
                break
            }
        return Event.NO_EVENT
        }

    fileprivate func parseEscape() -> Event
        {
        if !nextCh() { return Event.SUPPLY_MORE_INPUT }
        switch cc
            {
            case CH_b: buffer.append(CH_BS); dState = DataState.STRING; break
            case CH_f: buffer.append(CH_FF); dState = DataState.STRING; break
            case CH_n: buffer.append(CH_LF); dState = DataState.STRING; break
            case CH_r: buffer.append(CH_CR); dState = DataState.STRING; break
            case CH_t: buffer.append(CH_HT); dState = DataState.STRING; break
            case CH_u: hex = 0;              dState = DataState.HEX0;   break
            default:   buffer.append(cc);    dState = DataState.STRING; break
            }
        return Event.NO_EVENT
        }

    fileprivate func parseHexDigit(shift : Int, nextDState : DataState) -> Event
        {
        if !nextCh() { return Event.SUPPLY_MORE_INPUT }
        dState = nextDState
        hex = hex | (hexCharToNibble(cc) << shift)
        return Event.NO_EVENT
        }

    fileprivate func parseFinalHexDigit() -> Event
        {
        if !nextCh() { return Event.SUPPLY_MORE_INPUT }
        dState = DataState.STRING
        hex = hex | hexCharToNibble(cc)
        if hex <= 0x7F
            {
            buffer.append(UInt8(hex))
            }
        else if hex <= 0x7FF
            {
            buffer.append(UInt8(0xC0 | (hex >> 6)))
            buffer.append(UInt8(0x80 | (0x3F & hex)))
            }
        else
            {
            buffer.append(UInt8(0xE0 | (hex >> 12)))
            buffer.append(UInt8(0x80 | (0x3F & (hex >> 6))))
            buffer.append(UInt8(0x80 | (0x3F & hex)))
            }
        return Event.NO_EVENT
        }

    fileprivate func hexCharToNibble(_ ch : UInt8) -> Int
        {
        if ch >= CH_a
            {
            return Int(ch - CH_a)
            }
        else if ch >= CH_A
            {
            return Int(ch - CH_A)
            }
        else
            {
            return Int(ch - CH_0)
            }
        }

    fileprivate func parseRoot() -> Event
        {
        if done { return Event.END_JSON }
        if !nextChSkipWhitespace() { return Event.SUPPLY_MORE_INPUT }
        done = true
        switch cc
            {
            case CH_OPEN_BRACE:            pushJState(JsonState.OBJECT);                                                          return Event.START_OBJECT
            case CH_OPEN_SQUARE:           pushJState(JsonState.ARRAY);                                                           return Event.START_ARRAY
            case CH_APOSTROPHE, CH_QUOTES: buffer.removeAll(keepingCapacity: true); dState = DataState.STRING; quoteCh = cc;      break
            default:                       buffer.removeAll(keepingCapacity: true); dState = DataState.NUMBER; buffer.append(cc); break
            }
        return Event.NO_EVENT
        }

    fileprivate func parseArray() -> Event
        {
        if !nextChSkipWhitespace(andThisCh: CH_COMMA) { return Event.SUPPLY_MORE_INPUT }
        switch cc
            {
            case CH_CLOSE_SQUARE:          popJState();                                                                           return Event.END_ARRAY
            case CH_OPEN_BRACE:            pushJState(JsonState.OBJECT);                                                          return Event.START_OBJECT
            case CH_OPEN_SQUARE:           pushJState(JsonState.ARRAY);                                                           return Event.START_ARRAY
            case CH_APOSTROPHE, CH_QUOTES: buffer.removeAll(keepingCapacity: true); dState = DataState.STRING; quoteCh = cc;      break
            default:                       buffer.removeAll(keepingCapacity: true); dState = DataState.NUMBER; buffer.append(cc); break
            }
        return Event.NO_EVENT
        }

    fileprivate func parseObject() -> Event
        {
        if !nextChSkipWhitespace(andThisCh: CH_COMMA) { return Event.SUPPLY_MORE_INPUT }
        switch cc
            {
            case CH_CLOSE_BRACE:
                popJState()
                return Event.END_OBJECT
            case CH_APOSTROPHE, CH_QUOTES:
                jState = JsonState.OBJECT_NAME
                dState = DataState.STRING
                quoteCh = cc
                buffer.removeAll(keepingCapacity: true)
                return Event.NO_EVENT
            default:
                return Event.JSON_FORMAT_ERROR
            }
        }

    fileprivate func parseObjectName() -> Event
        {
        if !nextChSkipWhitespace(andThisCh: CH_COLON) { return Event.SUPPLY_MORE_INPUT }
        jState = JsonState.OBJECT_VALUE
        if cc == CH_OPEN_BRACE
            {
            pushJState(JsonState.OBJECT)
            return Event.START_OBJECT
            }
        if cc == CH_OPEN_SQUARE
            {
            pushJState(JsonState.ARRAY)
            return Event.START_ARRAY
            }
        if cc == CH_APOSTROPHE || cc == CH_QUOTES
            {
            buffer.removeAll(keepingCapacity: true)
            dState = DataState.STRING
            quoteCh = cc
            }
        else
            {
            buffer.removeAll(keepingCapacity: true)
            dState = DataState.NUMBER
            backup1Char()
            }
        return Event.NO_EVENT
        }

    fileprivate func parseObjectValue() -> Event
        {
        jState = JsonState.OBJECT
        return Event.END_NVP
        }

    fileprivate var jState : JsonState
        {
        get     { return jStates[jStateIndex] }
        set(js) { jStates[jStateIndex] = js   }
        }

    fileprivate func pushJState(_ js : JsonState)
        {
        jStateIndex += 1
        if jStateIndex >= jStates.count
            { jStates.append(js) }
        else
            { jStates[jStateIndex] = js }
        }

    fileprivate func popJState()
        {
        if jStateIndex <= 0 { print("Too many JState pops!"); abort() }
        jStateIndex -= 1
        }

    fileprivate func nextCh() -> Bool
        {
        if jsonTextIndex < jsonTextIndexRoof
            {
            cc = jsonText[jsonTextIndex]
            jsonTextIndex += 1
            return true
            }
        else
            { return false }
        }

    fileprivate func nextChSkipWhitespace() -> Bool
        {
        while nextCh() { if !isWhitespace(cc) { return true } }
        return false
        }

    fileprivate func nextChSkipWhitespace(andThisCh : UInt8) -> Bool
        {
        while nextChSkipWhitespace() { if cc != andThisCh { return true } }
        return false
        }

    fileprivate func backup1Char()
        {
        jsonTextIndex -= 1
        }

    fileprivate func isWhitespace(_ byte : UInt8) -> Bool
        {
        switch byte
            {
            case CH_HT:    return true
            case CH_SPACE: return true
            case CH_CR:    return true
            case CH_LF:    return true
            default:       return false
            }
        }

    fileprivate func isNumericTerminator(_ byte : UInt8) -> Bool
        {
        if isWhitespace(byte) { return true }
        switch byte
            {
            case CH_COMMA:        return true
            case CH_CLOSE_SQUARE: return true
            case CH_CLOSE_BRACE:  return true
            default:              return false
            }
        }
    }
