#pragma once

/*
 * Vendor copy of IHateMyKite/DeviousDevicesNG include/API.h (DD_APIVERSION 2).
 * Do not include DeviceReader.h. Do not use Export.h.
 * Load via GetModuleHandle + GetProcAddress("GetAPI") — never link DeviousDevices.dll.
 * Call LoadAPI only on the BondagePanel path after DDNG DeviceReader::Setup
 * (kPostLoadGame / kNewGame). Core plugin init must not require this DLL.
 */

#include <map>
#include <memory>
#include <string>
#include <vector>

#define DD_APIVERSION 2U

namespace DeviousDevicesAPI
{
    struct DeviceModPrototype
    {
        std::string name;
        uint8_t group_TES4[32];
        uint8_t group_ARMO[32];
        size_t size;
        uint8_t* rawdata = nullptr;
        std::vector<uint8_t[16]> devicerecords;
        std::vector<std::string> masters;
    };

    struct DeviceUnitPrototype
    {
        std::string scriptName;

        RE::BGSKeyword* kwd = nullptr;

        RE::BGSMessage* equipMenu = nullptr;
        RE::BGSMessage* zad_DD_OnPutOnDevice = nullptr;
        RE::BGSMessage* zad_EquipRequiredFailMsg = nullptr;
        RE::BGSMessage* zad_EquipConflictFailMsg = nullptr;

        std::vector<RE::BGSKeyword*> equipConflictingDeviceKwds;
        std::vector<RE::BGSKeyword*> requiredDeviceKwds;
        std::vector<RE::BGSKeyword*> unequipConflictingDeviceKwds;

        bool lockable;
        bool canManipulate;

        RE::TESObjectARMO* deviceInventory = nullptr;
        RE::TESObjectARMO* deviceRendered = nullptr;

        uint8_t padd_A[16];
        std::vector<RE::BGSKeyword*> keywords;
        std::shared_ptr<DeviceModPrototype> deviceMod;

        struct HistoryRecord
        {
            std::shared_ptr<DeviceModPrototype> deviceMod;
            uint8_t padd_CB[16];
            std::vector<RE::BGSKeyword*> keywords;
        };
        std::vector<HistoryRecord> history;
    };

    enum BondageState : uint32_t {
        sNone = 0x0000,
        sHandsBound = 0x0001,
        sHandsBoundNoAnim = 0x0002,
        sGaggedBlocking = 0x0004,
        sChastifiedGenital = 0x0008,
        sChastifiedAnal = 0x0010,
        sChastifiedBreasts = 0x0020,
        sBlindfolded = 0x0040,
        sMittens = 0x0080,
        sBoots = 0x0100,
        sTotal = 0x0200
    };

    class DeviousDevicesAPI
    {
    public:
        virtual size_t GetVersion() const = 0;
        virtual const std::map<RE::TESObjectARMO*, DeviceUnitPrototype>& GetDatabase() const = 0;
        virtual RE::TESObjectARMO* GetDeviceRender(RE::TESObjectARMO* a_invdevice) const = 0;
        virtual RE::TESObjectARMO* GetDeviceInventory(RE::TESObjectARMO* a_renddevice) const = 0;
        virtual RE::TESForm* GetPropertyForm(RE::TESObjectARMO* a_invdevice, std::string a_propertyname,
            RE::TESForm* a_defvalue, int a_mode) const = 0;
        virtual int GetPropertyInt(RE::TESObjectARMO* a_invdevice, std::string a_propertyname, int a_defvalue,
            int a_mode) const = 0;
        virtual float GetPropertyFloat(RE::TESObjectARMO* a_invdevice, std::string a_propertyname, float a_defvalue,
            int a_mode) const = 0;
        virtual bool GetPropertyBool(RE::TESObjectARMO* a_invdevice, std::string a_propertyname, bool a_defvalue,
            int a_mode) const = 0;
        virtual std::string GetPropertyString(RE::TESObjectARMO* a_invdevice, std::string a_propertyname,
            std::string a_defvalue, int a_mode) const = 0;
        virtual std::vector<RE::TESForm*> GetPropertyFormArray(RE::TESObjectARMO* a_invdevice,
            std::string a_propertyname, int a_mode) const = 0;
        virtual std::vector<int> GetPropertyIntArray(RE::TESObjectARMO* a_invdevice, std::string a_propertyname,
            int a_mode) const = 0;
        virtual std::vector<float> GetPropertyFloatArray(RE::TESObjectARMO* a_invdevice, std::string a_propertyname,
            int a_mode) const = 0;
        virtual std::vector<bool> GetPropertyBoolArray(RE::TESObjectARMO* a_invdevice, std::string a_propertyname,
            int a_mode) const = 0;
        virtual std::vector<std::string> GetPropertyStringArray(RE::TESObjectARMO* a_invdevice,
            std::string a_propertyname, int a_mode) const = 0;
        virtual bool ApplyExpression(RE::Actor* a_actor, const std::vector<float>& a_expression, float a_strength,
            bool a_openMouth, int a_priority) const = 0;
        virtual bool ResetExpression(RE::Actor* a_actor, int a_priority) const = 0;
        virtual void UpdateGagExpression(RE::Actor* a_actor) const = 0;
        virtual void ResetGagExpression(RE::Actor* a_actor) const = 0;
        virtual bool IsGagged(RE::Actor* a_actor) const = 0;
        virtual bool RegisterGagType(RE::BGSKeyword* a_keyword, std::vector<RE::TESFaction*> a_factions,
            std::vector<int> a_defaults) const = 0;
        virtual bool RegisterDefaultGagType(std::vector<RE::TESFaction*> a_factions,
            std::vector<int> a_defaults) const = 0;
        virtual void SetActorStripped(RE::Actor* a_actor, bool a_stripped, int a_armorfilter,
            int a_devicefilter) const = 0;
        virtual bool IsActorStripped(RE::Actor* a_actor) const = 0;
        virtual bool IsValidForHide(RE::TESObjectARMO* a_armor) const = 0;
        virtual std::vector<RE::TESObjectARMO*> GetDevices(RE::Actor* a_actor, int a_mode, bool a_worn) const = 0;
        virtual RE::TESObjectARMO* GetWornDevice(RE::Actor* a_actor, RE::BGSKeyword* a_kw, bool a_fuzzy) const = 0;
        virtual std::vector<RE::TESObjectARMO*> GetWornDevices(RE::Actor* a_actor) const = 0;
        virtual RE::TESObjectARMO* GetHandRestrain(RE::Actor* a_actor) const = 0;
        virtual BondageState GetBondageState(RE::Actor* a_actor) const = 0;
        virtual bool IsDevice(RE::TESObjectARMO* a_obj) const = 0;
        virtual bool ActorHasBlockingGag(RE::Actor* a_actor, RE::TESObjectARMO* a_gag = nullptr) const = 0;
    };

    inline DeviousDevicesAPI* g_API = nullptr;

    inline bool DllLoaded()
    {
        return GetModuleHandleW(L"DeviousDevices.dll") != nullptr;
    }

    inline bool LoadAPI()
    {
        if (g_API != nullptr)
            return true;
        HMODULE dllHandle = GetModuleHandleW(L"DeviousDevices.dll");
        if (!dllHandle)
            return false;
        auto pGetAPI = reinterpret_cast<DeviousDevicesAPI* (*)()>(GetProcAddress(dllHandle, "GetAPI"));
        if (!pGetAPI)
            return false;
        auto* loc_api = pGetAPI();
        if (loc_api != nullptr && loc_api->GetVersion() == DD_APIVERSION) {
            g_API = loc_api;
            return true;
        }
        return false;
    }
}
