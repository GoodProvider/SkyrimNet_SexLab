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

        // Registers Fn with the VM's (vm, stackID) prefix and publishes them for the call, so a
        // dead-handle error can trace the calling Papyrus stack (JsonStore CallerScope).
        template <auto Fn>
        struct WithCaller;

        template <class R, class... Args, R (*Fn)(RE::StaticFunctionTag*, Args...)>
        struct WithCaller<Fn>
        {
            static R Call(RE::BSScript::IVirtualMachine* vm, RE::VMStackID stackID, RE::StaticFunctionTag* tag, Args... args)
            {
                SexLabNet::Json::CallerScope scope(vm, stackID);
                return Fn(tag, args...);
            }
        };

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
        a_vm->RegisterFunction("retain", jvalue, WithCaller<Value_retain>::Call, true);
        a_vm->RegisterFunction("release", jvalue, WithCaller<Value_release>::Call, true);
        a_vm->RegisterFunction("releaseAndRetain", jvalue, WithCaller<Value_releaseAndRetain>::Call, true);
        a_vm->RegisterFunction("isExists", jvalue, WithCaller<Value_isExists>::Call, true);
        a_vm->RegisterFunction("isArray", jvalue, WithCaller<Value_isArray>::Call, true);
        a_vm->RegisterFunction("isMap", jvalue, WithCaller<Value_isMap>::Call, true);
        a_vm->RegisterFunction("isFormMap", jvalue, WithCaller<Value_isFormMap>::Call, true);
        a_vm->RegisterFunction("isIntegerMap", jvalue, WithCaller<Value_isIntegerMap>::Call, true);
        a_vm->RegisterFunction("count", jvalue, WithCaller<Value_count>::Call, true);
        a_vm->RegisterFunction("objectFromPrototype", jvalue, WithCaller<Value_objectFromPrototype>::Call, true);
        a_vm->RegisterFunction("readFromFile", jvalue, WithCaller<Value_readFromFile>::Call, true);
        a_vm->RegisterFunction("writeToFile", jvalue, WithCaller<Value_writeToFile>::Call, true);
        a_vm->RegisterFunction("dump", jvalue, WithCaller<Value_dump>::Call, true);
        a_vm->RegisterFunction("stats", jvalue, WithCaller<Value_stats>::Call, true);

        constexpr std::string_view jmap = "SNSL_JMap";
        a_vm->RegisterFunction("object", jmap, WithCaller<Map_object>::Call, true);
        a_vm->RegisterFunction("getInt", jmap, WithCaller<Map_getInt>::Call, true);
        a_vm->RegisterFunction("getFlt", jmap, WithCaller<Map_getFlt>::Call, true);
        a_vm->RegisterFunction("getStr", jmap, WithCaller<Map_getStr>::Call, true);
        a_vm->RegisterFunction("getObj", jmap, WithCaller<Map_getObj>::Call, true);
        a_vm->RegisterFunction("getForm", jmap, WithCaller<Map_getForm>::Call);
        a_vm->RegisterFunction("setInt", jmap, WithCaller<Map_setInt>::Call, true);
        a_vm->RegisterFunction("setFlt", jmap, WithCaller<Map_setFlt>::Call, true);
        a_vm->RegisterFunction("setStr", jmap, WithCaller<Map_setStr>::Call, true);
        a_vm->RegisterFunction("setObj", jmap, WithCaller<Map_setObj>::Call, true);
        a_vm->RegisterFunction("setForm", jmap, WithCaller<Map_setForm>::Call);
        a_vm->RegisterFunction("valueType", jmap, WithCaller<Map_valueType>::Call, true);
        a_vm->RegisterFunction("nextKey", jmap, WithCaller<Map_nextKey>::Call, true);
        a_vm->RegisterFunction("allKeys", jmap, WithCaller<Map_allKeys>::Call, true);
        a_vm->RegisterFunction("count", jmap, WithCaller<Map_count>::Call, true);
        a_vm->RegisterFunction("hasKey", jmap, WithCaller<Map_hasKey>::Call, true);
        a_vm->RegisterFunction("removeKey", jmap, WithCaller<Map_removeKey>::Call, true);
        a_vm->RegisterFunction("clear", jmap, WithCaller<Map_clear>::Call, true);

        constexpr std::string_view jarray = "SNSL_JArray";
        a_vm->RegisterFunction("object", jarray, WithCaller<Array_object>::Call, true);
        a_vm->RegisterFunction("objectWithSize", jarray, WithCaller<Array_objectWithSize>::Call, true);
        a_vm->RegisterFunction("getInt", jarray, WithCaller<Array_getInt>::Call, true);
        a_vm->RegisterFunction("getFlt", jarray, WithCaller<Array_getFlt>::Call, true);
        a_vm->RegisterFunction("getStr", jarray, WithCaller<Array_getStr>::Call, true);
        a_vm->RegisterFunction("getObj", jarray, WithCaller<Array_getObj>::Call, true);
        a_vm->RegisterFunction("getForm", jarray, WithCaller<Array_getForm>::Call);
        a_vm->RegisterFunction("setInt", jarray, WithCaller<Array_setInt>::Call, true);
        a_vm->RegisterFunction("setFlt", jarray, WithCaller<Array_setFlt>::Call, true);
        a_vm->RegisterFunction("setStr", jarray, WithCaller<Array_setStr>::Call, true);
        a_vm->RegisterFunction("setObj", jarray, WithCaller<Array_setObj>::Call, true);
        a_vm->RegisterFunction("setForm", jarray, WithCaller<Array_setForm>::Call);
        a_vm->RegisterFunction("addInt", jarray, WithCaller<Array_addInt>::Call, true);
        a_vm->RegisterFunction("addFlt", jarray, WithCaller<Array_addFlt>::Call, true);
        a_vm->RegisterFunction("addStr", jarray, WithCaller<Array_addStr>::Call, true);
        a_vm->RegisterFunction("addObj", jarray, WithCaller<Array_addObj>::Call, true);
        a_vm->RegisterFunction("addForm", jarray, WithCaller<Array_addForm>::Call);
        a_vm->RegisterFunction("count", jarray, WithCaller<Array_count>::Call, true);
        a_vm->RegisterFunction("valueType", jarray, WithCaller<Array_valueType>::Call, true);
        a_vm->RegisterFunction("eraseIndex", jarray, WithCaller<Array_eraseIndex>::Call, true);
        a_vm->RegisterFunction("findForm", jarray, WithCaller<Array_findForm>::Call);
        a_vm->RegisterFunction("clear", jarray, WithCaller<Array_clear>::Call, true);

        constexpr std::string_view jformmap = "SNSL_JFormMap";
        a_vm->RegisterFunction("object", jformmap, WithCaller<FormMap_object>::Call);
        a_vm->RegisterFunction("getObj", jformmap, WithCaller<FormMap_getObj>::Call);
        a_vm->RegisterFunction("setObj", jformmap, WithCaller<FormMap_setObj>::Call);
        a_vm->RegisterFunction("valueType", jformmap, WithCaller<FormMap_valueType>::Call);
        a_vm->RegisterFunction("nextKey", jformmap, WithCaller<FormMap_nextKey>::Call);

        webui_log::info("Successfully registered Papyrus functions for SNSL_JValue/JMap/JArray/JFormMap");
        return true;
    }
}
