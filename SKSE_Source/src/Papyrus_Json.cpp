#include "Papyrus_Json.h"
#include "JsonStore.h"
#include "WebUI_Log.h"

namespace PapyrusBindings_Json
{
    using SexLabNet::Json::Handle;

    namespace
    {
        std::string Str(RE::BSFixedString s) { return s.c_str() ? std::string(s.c_str()) : std::string(); }
        RE::BSFixedString Bfs(const std::string& s) { return RE::BSFixedString(s); }

        // --- SNSL_JValue ---

        std::int32_t Value_retain(RE::StaticFunctionTag*, std::int32_t object, RE::BSFixedString) { return SexLabNet::Json::Retain(object); }
        std::int32_t Value_release(RE::StaticFunctionTag*, std::int32_t object) { return SexLabNet::Json::Release(object); }
        std::int32_t Value_releaseAndRetain(RE::StaticFunctionTag*, std::int32_t previousObject, std::int32_t newObject, RE::BSFixedString) {
            return SexLabNet::Json::ReleaseAndRetain(previousObject, newObject);
        }
        bool Value_isExists(RE::StaticFunctionTag*, std::int32_t object) { return SexLabNet::Json::IsValid(object); }
        bool Value_isArray(RE::StaticFunctionTag*, std::int32_t object) { return SexLabNet::Json::IsArray(object); }
        bool Value_isMap(RE::StaticFunctionTag*, std::int32_t object) { return SexLabNet::Json::IsMap(object); }
        bool Value_isFormMap(RE::StaticFunctionTag*, std::int32_t object) { return SexLabNet::Json::IsFormMap(object); }
        bool Value_isIntegerMap(RE::StaticFunctionTag*, std::int32_t) { return false; }
        std::int32_t Value_count(RE::StaticFunctionTag*, std::int32_t object) { return SexLabNet::Json::Count(object); }
        std::int32_t Value_objectFromPrototype(RE::StaticFunctionTag*, RE::BSFixedString prototype) { return SexLabNet::Json::FromJsonPrototype(Str(prototype)); }
        std::int32_t Value_readFromFile(RE::StaticFunctionTag*, RE::BSFixedString filePath) { return SexLabNet::Json::ReadFromFile(Str(filePath)); }
        void Value_writeToFile(RE::StaticFunctionTag*, std::int32_t object, RE::BSFixedString filePath) { SexLabNet::Json::WriteToFile(object, Str(filePath)); }
        RE::BSFixedString Value_dump(RE::StaticFunctionTag*, std::int32_t object) { return Bfs(SexLabNet::Json::Dump(object)); }
        RE::BSFixedString Value_stats(RE::StaticFunctionTag*) { return Bfs(SexLabNet::Json::Stats()); }

        // --- SNSL_JMap ---

        std::int32_t Map_object(RE::StaticFunctionTag*) { return SexLabNet::Json::NewMap(); }
        std::int32_t Map_getInt(RE::StaticFunctionTag*, std::int32_t object, RE::BSFixedString key, std::int32_t def) {
            return static_cast<std::int32_t>(SexLabNet::Json::MapGetInt(object, Str(key), def));
        }
        float Map_getFlt(RE::StaticFunctionTag*, std::int32_t object, RE::BSFixedString key, float def) {
            return static_cast<float>(SexLabNet::Json::MapGetFlt(object, Str(key), def));
        }
        RE::BSFixedString Map_getStr(RE::StaticFunctionTag*, std::int32_t object, RE::BSFixedString key, RE::BSFixedString def) {
            return Bfs(SexLabNet::Json::MapGetStr(object, Str(key), Str(def)));
        }
        std::int32_t Map_getObj(RE::StaticFunctionTag*, std::int32_t object, RE::BSFixedString key, std::int32_t def) {
            return SexLabNet::Json::MapGetObj(object, Str(key), def);
        }
        RE::TESForm* Map_getForm(RE::StaticFunctionTag*, std::int32_t object, RE::BSFixedString key, RE::TESForm* def) {
            return SexLabNet::Json::MapGetForm(object, Str(key), def);
        }
        void Map_setInt(RE::StaticFunctionTag*, std::int32_t object, RE::BSFixedString key, std::int32_t value) { SexLabNet::Json::MapSetInt(object, Str(key), value); }
        void Map_setFlt(RE::StaticFunctionTag*, std::int32_t object, RE::BSFixedString key, float value) { SexLabNet::Json::MapSetFlt(object, Str(key), value); }
        void Map_setStr(RE::StaticFunctionTag*, std::int32_t object, RE::BSFixedString key, RE::BSFixedString value) { SexLabNet::Json::MapSetStr(object, Str(key), Str(value)); }
        void Map_setObj(RE::StaticFunctionTag*, std::int32_t object, RE::BSFixedString key, std::int32_t container) { SexLabNet::Json::MapSetObj(object, Str(key), container); }
        void Map_setForm(RE::StaticFunctionTag*, std::int32_t object, RE::BSFixedString key, RE::TESForm* value) { SexLabNet::Json::MapSetForm(object, Str(key), value); }
        std::int32_t Map_valueType(RE::StaticFunctionTag*, std::int32_t object, RE::BSFixedString key) { return SexLabNet::Json::MapValueType(object, Str(key)); }
        RE::BSFixedString Map_nextKey(RE::StaticFunctionTag*, std::int32_t object, RE::BSFixedString previousKey, RE::BSFixedString endKey) {
            return Bfs(SexLabNet::Json::MapNextKey(object, Str(previousKey), Str(endKey)));
        }
        std::int32_t Map_allKeys(RE::StaticFunctionTag*, std::int32_t object) { return SexLabNet::Json::MapAllKeys(object); }
        std::int32_t Map_count(RE::StaticFunctionTag*, std::int32_t object) { return SexLabNet::Json::Count(object); }
        bool Map_hasKey(RE::StaticFunctionTag*, std::int32_t object, RE::BSFixedString key) { return SexLabNet::Json::MapHasKey(object, Str(key)); }
        void Map_removeKey(RE::StaticFunctionTag*, std::int32_t object, RE::BSFixedString key) { SexLabNet::Json::MapRemoveKey(object, Str(key)); }
        void Map_clear(RE::StaticFunctionTag*, std::int32_t object) { SexLabNet::Json::MapClear(object); }

        // --- SNSL_JArray ---

        std::int32_t Array_object(RE::StaticFunctionTag*) { return SexLabNet::Json::NewArray(); }
        std::int32_t Array_objectWithSize(RE::StaticFunctionTag*, std::int32_t size) { return SexLabNet::Json::NewArrayWithSize(size); }
        std::int32_t Array_getInt(RE::StaticFunctionTag*, std::int32_t object, std::int32_t index, std::int32_t def) {
            return static_cast<std::int32_t>(SexLabNet::Json::ArrayGetInt(object, index, def));
        }
        float Array_getFlt(RE::StaticFunctionTag*, std::int32_t object, std::int32_t index, float def) {
            return static_cast<float>(SexLabNet::Json::ArrayGetFlt(object, index, def));
        }
        RE::BSFixedString Array_getStr(RE::StaticFunctionTag*, std::int32_t object, std::int32_t index, RE::BSFixedString def) {
            return Bfs(SexLabNet::Json::ArrayGetStr(object, index, Str(def)));
        }
        std::int32_t Array_getObj(RE::StaticFunctionTag*, std::int32_t object, std::int32_t index, std::int32_t def) {
            return SexLabNet::Json::ArrayGetObj(object, index, def);
        }
        RE::TESForm* Array_getForm(RE::StaticFunctionTag*, std::int32_t object, std::int32_t index, RE::TESForm* def) {
            return SexLabNet::Json::ArrayGetForm(object, index, def);
        }
        void Array_setInt(RE::StaticFunctionTag*, std::int32_t object, std::int32_t index, std::int32_t value) { SexLabNet::Json::ArraySetInt(object, index, value); }
        void Array_setFlt(RE::StaticFunctionTag*, std::int32_t object, std::int32_t index, float value) { SexLabNet::Json::ArraySetFlt(object, index, value); }
        void Array_setStr(RE::StaticFunctionTag*, std::int32_t object, std::int32_t index, RE::BSFixedString value) { SexLabNet::Json::ArraySetStr(object, index, Str(value)); }
        void Array_setObj(RE::StaticFunctionTag*, std::int32_t object, std::int32_t index, std::int32_t container) { SexLabNet::Json::ArraySetObj(object, index, container); }
        void Array_setForm(RE::StaticFunctionTag*, std::int32_t object, std::int32_t index, RE::TESForm* value) { SexLabNet::Json::ArraySetForm(object, index, value); }
        void Array_addInt(RE::StaticFunctionTag*, std::int32_t object, std::int32_t value, std::int32_t addToIndex) { SexLabNet::Json::ArrayAddInt(object, value, addToIndex); }
        void Array_addFlt(RE::StaticFunctionTag*, std::int32_t object, float value, std::int32_t addToIndex) { SexLabNet::Json::ArrayAddFlt(object, value, addToIndex); }
        void Array_addStr(RE::StaticFunctionTag*, std::int32_t object, RE::BSFixedString value, std::int32_t addToIndex) { SexLabNet::Json::ArrayAddStr(object, Str(value), addToIndex); }
        void Array_addObj(RE::StaticFunctionTag*, std::int32_t object, std::int32_t container, std::int32_t addToIndex) { SexLabNet::Json::ArrayAddObj(object, container, addToIndex); }
        void Array_addForm(RE::StaticFunctionTag*, std::int32_t object, RE::TESForm* value, std::int32_t addToIndex) { SexLabNet::Json::ArrayAddForm(object, value, addToIndex); }
        std::int32_t Array_count(RE::StaticFunctionTag*, std::int32_t object) { return SexLabNet::Json::Count(object); }
        std::int32_t Array_valueType(RE::StaticFunctionTag*, std::int32_t object, std::int32_t index) { return SexLabNet::Json::ArrayValueType(object, index); }
        void Array_eraseIndex(RE::StaticFunctionTag*, std::int32_t object, std::int32_t index) { SexLabNet::Json::ArrayEraseIndex(object, index); }
        std::int32_t Array_findForm(RE::StaticFunctionTag*, std::int32_t object, RE::TESForm* form) { return SexLabNet::Json::ArrayFindForm(object, form); }
        void Array_clear(RE::StaticFunctionTag*, std::int32_t object) { SexLabNet::Json::ArrayClear(object); }

        // --- SNSL_JFormMap ---

        std::int32_t FormMap_object(RE::StaticFunctionTag*) { return SexLabNet::Json::NewFormMap(); }
        std::int32_t FormMap_getObj(RE::StaticFunctionTag*, std::int32_t object, RE::TESForm* key, std::int32_t def) {
            return SexLabNet::Json::FormMapGetObj(object, key, def);
        }
        void FormMap_setObj(RE::StaticFunctionTag*, std::int32_t object, RE::TESForm* key, std::int32_t container) { SexLabNet::Json::FormMapSetObj(object, key, container); }
        std::int32_t FormMap_valueType(RE::StaticFunctionTag*, std::int32_t object, RE::TESForm* key) { return SexLabNet::Json::FormMapValueType(object, key); }
        RE::TESForm* FormMap_nextKey(RE::StaticFunctionTag*, std::int32_t object, RE::TESForm* previousKey, RE::TESForm* endKey) {
            return SexLabNet::Json::FormMapNextKey(object, previousKey, endKey);
        }
    }

    bool Register_Json_Functions(RE::BSScript::IVirtualMachine* a_vm)
    {
        if (!a_vm) {
            webui_log::error("Couldn't get Papyrus Virtual Machine.");
            return false;
        }

        constexpr std::string_view jvalue = "SNSL_JValue";
        a_vm->RegisterFunction("retain", jvalue, Value_retain, true);
        a_vm->RegisterFunction("release", jvalue, Value_release, true);
        a_vm->RegisterFunction("releaseAndRetain", jvalue, Value_releaseAndRetain, true);
        a_vm->RegisterFunction("isExists", jvalue, Value_isExists, true);
        a_vm->RegisterFunction("isArray", jvalue, Value_isArray, true);
        a_vm->RegisterFunction("isMap", jvalue, Value_isMap, true);
        a_vm->RegisterFunction("isFormMap", jvalue, Value_isFormMap, true);
        a_vm->RegisterFunction("isIntegerMap", jvalue, Value_isIntegerMap, true);
        a_vm->RegisterFunction("count", jvalue, Value_count, true);
        a_vm->RegisterFunction("objectFromPrototype", jvalue, Value_objectFromPrototype, true);
        a_vm->RegisterFunction("readFromFile", jvalue, Value_readFromFile, true);
        a_vm->RegisterFunction("writeToFile", jvalue, Value_writeToFile, true);
        a_vm->RegisterFunction("dump", jvalue, Value_dump, true);
        a_vm->RegisterFunction("stats", jvalue, Value_stats, true);

        constexpr std::string_view jmap = "SNSL_JMap";
        a_vm->RegisterFunction("object", jmap, Map_object, true);
        a_vm->RegisterFunction("getInt", jmap, Map_getInt, true);
        a_vm->RegisterFunction("getFlt", jmap, Map_getFlt, true);
        a_vm->RegisterFunction("getStr", jmap, Map_getStr, true);
        a_vm->RegisterFunction("getObj", jmap, Map_getObj, true);
        a_vm->RegisterFunction("getForm", jmap, Map_getForm);
        a_vm->RegisterFunction("setInt", jmap, Map_setInt, true);
        a_vm->RegisterFunction("setFlt", jmap, Map_setFlt, true);
        a_vm->RegisterFunction("setStr", jmap, Map_setStr, true);
        a_vm->RegisterFunction("setObj", jmap, Map_setObj, true);
        a_vm->RegisterFunction("setForm", jmap, Map_setForm);
        a_vm->RegisterFunction("valueType", jmap, Map_valueType, true);
        a_vm->RegisterFunction("nextKey", jmap, Map_nextKey, true);
        a_vm->RegisterFunction("allKeys", jmap, Map_allKeys, true);
        a_vm->RegisterFunction("count", jmap, Map_count, true);
        a_vm->RegisterFunction("hasKey", jmap, Map_hasKey, true);
        a_vm->RegisterFunction("removeKey", jmap, Map_removeKey, true);
        a_vm->RegisterFunction("clear", jmap, Map_clear, true);

        constexpr std::string_view jarray = "SNSL_JArray";
        a_vm->RegisterFunction("object", jarray, Array_object, true);
        a_vm->RegisterFunction("objectWithSize", jarray, Array_objectWithSize, true);
        a_vm->RegisterFunction("getInt", jarray, Array_getInt, true);
        a_vm->RegisterFunction("getFlt", jarray, Array_getFlt, true);
        a_vm->RegisterFunction("getStr", jarray, Array_getStr, true);
        a_vm->RegisterFunction("getObj", jarray, Array_getObj, true);
        a_vm->RegisterFunction("getForm", jarray, Array_getForm);
        a_vm->RegisterFunction("setInt", jarray, Array_setInt, true);
        a_vm->RegisterFunction("setFlt", jarray, Array_setFlt, true);
        a_vm->RegisterFunction("setStr", jarray, Array_setStr, true);
        a_vm->RegisterFunction("setObj", jarray, Array_setObj, true);
        a_vm->RegisterFunction("setForm", jarray, Array_setForm);
        a_vm->RegisterFunction("addInt", jarray, Array_addInt, true);
        a_vm->RegisterFunction("addFlt", jarray, Array_addFlt, true);
        a_vm->RegisterFunction("addStr", jarray, Array_addStr, true);
        a_vm->RegisterFunction("addObj", jarray, Array_addObj, true);
        a_vm->RegisterFunction("addForm", jarray, Array_addForm);
        a_vm->RegisterFunction("count", jarray, Array_count, true);
        a_vm->RegisterFunction("valueType", jarray, Array_valueType, true);
        a_vm->RegisterFunction("eraseIndex", jarray, Array_eraseIndex, true);
        a_vm->RegisterFunction("findForm", jarray, Array_findForm);
        a_vm->RegisterFunction("clear", jarray, Array_clear, true);

        constexpr std::string_view jformmap = "SNSL_JFormMap";
        a_vm->RegisterFunction("object", jformmap, FormMap_object);
        a_vm->RegisterFunction("getObj", jformmap, FormMap_getObj);
        a_vm->RegisterFunction("setObj", jformmap, FormMap_setObj);
        a_vm->RegisterFunction("valueType", jformmap, FormMap_valueType);
        a_vm->RegisterFunction("nextKey", jformmap, FormMap_nextKey);

        webui_log::info("Successfully registered Papyrus functions for SNSL_JValue/JMap/JArray/JFormMap");
        return true;
    }
}
