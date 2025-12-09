package com.github.itsgromit.fabricaa.mixin.client;

import com.github.itsgromit.fabricaa.client.FabricaaClient;
import net.minecraft.client.render.*;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

@Mixin(GameRenderer.class)
public class GameRendererMixin {

    @Inject(
            method = "renderWorld",
            at = @At("RETURN")
    )
    private void afterWorldBeforeHand(RenderTickCounter tickCounter, CallbackInfo ci) {
        // Apply post-processing to world only, before hand and GUI are rendered
        FabricaaClient.applyPostProcessing(tickCounter.getTickDelta(true));
    }
}
