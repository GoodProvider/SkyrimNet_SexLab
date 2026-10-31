#include "RE/T/TESWaterSystem.h"
#include "RE/B/BSGeometry.h"

namespace RE
{
	TESWaterSystem* TESWaterSystem::GetSingleton()
	{
		static REL::Relocation<TESWaterSystem**> singleton{ RELOCATION_ID(514290, 400450) };
		return *singleton;
	}

	void TESWaterSystem::AddRipple(const NiPoint3& a_pos, float a_scale)
	{
		using func_t = decltype(&TESWaterSystem::AddRipple);
		static REL::Relocation<func_t> func{ RELOCATION_ID(31410, 32217) };
		return func(this, a_pos, a_scale);
	}

	void TESWaterSystem::Enable()
	{
		using func_t = decltype(&TESWaterSystem::Enable);
		static REL::Relocation<func_t> func{ RELOCATION_ID(31406, 32213) };
		return func(this);
	}

	void TESWaterSystem::AddWater(NiAVObject* a_waterObj, TESWaterForm* a_waterType, float a_waterHeight, const BSTArray<NiPointer<BSMultiBoundAABB>>* a_multiBoundShape, bool a_noDisplacement, bool a_isProcedural)
	{
		using func_t = decltype(&TESWaterSystem::AddWater);
		static REL::Relocation<func_t> func{ RELOCATION_ID(31388, 32179) };
		return func(this, a_waterObj, a_waterType, a_waterHeight, a_multiBoundShape, a_noDisplacement, a_isProcedural);
	}

	bool TESWaterSystem::RemoveWater(NiAVObject* a_waterObj)
	{
		using func_t = decltype(&TESWaterSystem::RemoveWater);
		static REL::Relocation<func_t> func{ RELOCATION_ID(31391, 32182) };
		return func(this, a_waterObj);
	}
}
