package com.github.itsgromit.fabricaa.mixin.client;

import net.minecraft.client.MinecraftClient;
import net.minecraft.client.util.Window;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

@Mixin(Window.class)
public class WindowMixin {

    /**
     * Force the main framebuffer to match the actual window resolution
     * whenever the framebuffer size is updated.
     */
    @Inject(method = "onFramebufferSizeChanged", at = @At("TAIL"))
    private void onFramebufferSizeChanged(long window, int width, int height, CallbackInfo ci) {
        MinecraftClient mc = MinecraftClient.getInstance();
        if (mc != null && mc.getFramebuffer() != null) {
            // Ensure the main framebuffer matches the actual window size
            mc.getFramebuffer().resize(width, height, MinecraftClient.IS_SYSTEM_MAC);
        }
    }
}