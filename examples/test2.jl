using Blend2D, ColorTypes, Images, FileIO

blRuntimeInit()

s = BLSizeI(16, 7)

image = BLImageCore()
@show blImageInitAs(image, s.w, s.h, BL_FORMAT_PRGB32)

path = BLPathCore()
blPathInit(path)
blPathMoveTo(path, 0.0, 0.0)
blPathLineTo(path, Float64(s.w-1), Float64(s.h-1))

ctx = BLContextCore()
@show blContextInit(ctx)
@show blContextBegin(ctx, image, BLContextCreateInfo())
@show blContextSetFillStyleRgba32(ctx, 0xffffffff)
@show blContextFillAll(ctx)
@show blContextSetStrokeStyleRgba32(ctx, 0xff0000ff)
@show blContextStrokePathD(ctx, path)
@show blContextEnd(ctx)

data = Blend2D.BLImageData()
@show Blend2D.blImageGetData(image, data)
@show data

arr = unsafe_wrap(Array, convert(Ptr{RGBA{N0f8}}, data.pixelData), (data.size.w, data.size.h))
arr2 = PermutedDimsArray(arr, (2, 1))

save("test2.png", arr2)