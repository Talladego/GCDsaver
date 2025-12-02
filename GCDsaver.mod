<?xml version="1.0" encoding="UTF-8"?>
<ModuleFile xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
	<UiMod name="GCDsaver" version="1.08" date="02/12/2025" >
		<Author name="Talladego, SWF" email="" />
		<Description text="GCDsaver" />
		<VersionSettings gameVersion="1.9.9" windowsVersion="1.0" savedVariablesVersion="1.0" />

		<Dependencies>
			<Dependency name="EA_ActionBars" />
			<Dependency name="LibSlash" />
		</Dependencies>
			
		<Files>
			<File name="libs\LibStub.lua" />
			<File name="libs\LibGUI.lua" />
			<File name="libs\LibConfig.lua" />		
			<File name="GCDsaver.lua" />			
			<File name="GCDsaver_Config.lua" />						
		</Files>

		<SavedVariables>
			<SavedVariable name="GCDsaver.Settings" />
		</SavedVariables>

		<OnInitialize>
			<CallFunction name="GCDsaver.Initialize" />
		</OnInitialize>

		<OnUpdate>
			<CallFunction name="GCDsaver.OnUpdate" />
		</OnUpdate>

		<OnShutdown>
			<CallFunction name="GCDsaver.OnShutdown" />
		</OnShutdown>
	</UiMod>
</ModuleFile>
