#pragma once

namespace RE
{
	namespace BSGraphics
	{
		enum class TextureFilterMode
		{
			kNearest,
			kBilinear,
			kTrilinear,
			kAnisotropic,
			kDefault = kAnisotropic,
			kCompBilinear,
		};
	}
}
