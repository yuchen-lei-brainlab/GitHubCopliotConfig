function gs  { p4 opened }
function bld { msbuild "C:\perforce\AnmaTest\BOLDMRIMapping\distribution\BOLDMRIMappingDistribution.bm2022.sln" /p:Configuration=04_VC143SharedRelease /p:Platform=x64 /m }
function bldd { msbuild "C:\perforce\AnmaTest\BOLDMRIMapping\distribution\BOLDMRIMappingDistribution.bm2022.sln" /p:Configuration=01_VC143SharedDebug /p:Platform=x64 /m }
function cdd   { Set-Location C:\perforce\AnmaTest\BOLDMRIMapping\distribution }
function bldc  { msbuild "C:\perforce\AnmaTest\BOLDMRIMapping\distribution\BOLDMRIMappingDistribution.bm2022.sln" /p:Configuration=01_VC143SharedDebug /p:Platform=x64 /m /t:Clean }
function rbld  { msbuild "C:\perforce\AnmaTest\BOLDMRIMapping\distribution\BOLDMRIMappingDistribution.bm2022.sln" /p:Configuration=01_VC143SharedDebug /p:Platform=x64 /m /t:Rebuild }
function bldq  { msbuild "C:\perforce\AnmaTest\BOLDMRIMapping\distribution\BOLDMRIMappingDistribution.bm2022.sln" /p:Configuration=01_VC143SharedDebug /p:Platform=x64 /m /v:minimal }
function p4s   { p4 status }
function p4d   { p4 diff }

