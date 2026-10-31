#pragma once

#include "RE/B/BGSTerrainNode.h"
#include "RE/B/BSTArray.h"

namespace RE
{
	class BGSTerrainNode;
	class TESWorldSpace;

	class BGSTerrainManager
	{
	public:
		std::uint64_t             unk00;                 // 00
		TESWorldSpace*            worldSpace;            // 08
		BGSTerrainNode*           rootNode;              // 10
		std::int16_t              minCellX;              // 18 - read from .lod file
		std::int16_t              minCellY;              // 1A - read from .lod file
		std::uint32_t             maxLevel;              // 1C - read from .lod file
		std::uint32_t             minLevel;              // 20 - read from .lod file
		std::uint32_t             rootLevel;             // 24 - read from .lod file
		std::uint32_t             segmentedBlockLevel;   // 28 - default 4
		std::uint32_t             treeLevel;             // 2C - default 4
		bool                      unk30;                 // 30
		std::uint8_t              unk31;                 // 31
		bool                      lodTreesHidden;        // 32
		std::uint8_t              unk33;                 // 33
		bool                      needsImmediateUpdate;  // 34
		std::uint8_t              unk35;                 // 35
		bool                      hasLOD;                // 36
		std::uint8_t              unk37;                 // 37
		std::uint64_t             unk38;                 // 38
		std::uint64_t             unk40;                 // 40
		std::uint64_t             unk48;                 // 48
		std::uint64_t             unk50;                 // 50
		std::uint64_t             unk58;                 // 58
		BSTArray<BGSTerrainNode*> updateNodes;           // 60
		std::uint32_t             nextUpdateNode;        // 78
		std::uint32_t             unk7C;                 // 7C
		BSTArray<BGSTerrainNode*> immediateUpdates;      // 80
		std::uint64_t             unk98;                 // 98 - BSSpinLock?
		std::uint64_t             unkA0;                 // A0
		std::uint64_t             unkA8;                 // A8
		std::uint64_t             unkB0;                 // B0
		std::uint64_t             unkB8;                 // B8
		std::uint64_t             unkC0;                 // C0
		std::uint64_t             unkC8;                 // C8
	};
	static_assert(sizeof(BGSTerrainManager) == 0xD0);
}
