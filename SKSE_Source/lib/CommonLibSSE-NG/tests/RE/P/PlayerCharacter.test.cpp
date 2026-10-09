#include "catch2/catch_all.hpp"

#include "RE/Skyrim.h"
#include "REL/REL.h"
#include "SKSE/SKSE.h"

TEST_CASE("PlayerCharacter/RuntimeDataOffsets")
{
	SECTION("Skyrim SE 1.5.97 uses the SE anchor")
	{
		REQUIRE(REL::Module::mock(SKSE::RUNTIME_SSE_1_5_97, REL::Module::Runtime::SE, L"SkyrimSE.exe", 0x1000));
		CHECK(RE::PlayerCharacter::PlayerRuntimeOffset(0x3D8, 0x9C8, 0x3E0) == 0x3D8);
		REL::Module::reset();
	}
	SECTION("Skyrim AE 1.6.1170 uses the AE anchor")
	{
		REQUIRE(REL::Module::mock(SKSE::RUNTIME_SSE_1_6_1170, REL::Module::Runtime::AE, L"SkyrimSE.exe", 0x1000));
		CHECK(RE::PlayerCharacter::PlayerRuntimeOffset(0x3D8, 0x9C8, 0x3E0) == 0x3E0);
		CHECK(RE::PlayerCharacter::PlayerRuntimeOffset(0x570, 0xB60, 0x578) == 0x578);
		REL::Module::reset();
	}
	SECTION("Skyrim 1.7.99 and 1.7.104 sit 0x8 above the AE anchor")
	{
		REQUIRE(REL::Module::mock(SKSE::RUNTIME_SSE_1_7_99, REL::Module::Runtime::AE, L"SkyrimSE.exe", 0x1000));
		CHECK(RE::PlayerCharacter::PlayerRuntimeOffset(0x3D8, 0x9C8, 0x3E0) == 0x3E8);
		CHECK(RE::PlayerCharacter::PlayerRuntimeOffset(0x570, 0xB60, 0x578) == 0x580);
		CHECK(RE::PlayerCharacter::PlayerRuntimeOffset(0x598, 0xB88, 0x5A0) == 0x5A8);
		REL::Module::reset();
		REQUIRE(REL::Module::mock(SKSE::RUNTIME_SSE_1_7_104, REL::Module::Runtime::AE, L"SkyrimSE.exe", 0x1000));
		CHECK(RE::PlayerCharacter::PlayerRuntimeOffset(0xBD8, 0x12D0, 0xBE0) == 0xBE8);
		REL::Module::reset();
	}
}
