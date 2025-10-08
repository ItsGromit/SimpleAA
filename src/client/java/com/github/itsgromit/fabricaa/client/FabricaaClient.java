package com.github.itsgromit.fabricaa.client;

import net.fabricmc.api.ClientModInitializer;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.fabricmc.fabric.api.client.keybinding.v1.KeyBindingHelper;
import net.fabricmc.fabric.api.resource.ResourceManagerHelper;
import net.fabricmc.fabric.api.resource.SimpleSynchronousResourceReloadListener;
import net.fabricmc.fabric.api.client.rendering.v1.WorldRenderEvents;

import net.minecraft.client.MinecraftClient;
import net.minecraft.client.option.KeyBinding;
import net.minecraft.client.util.InputUtil;
import net.minecraft.client.gl.PostEffectProcessor;
import net.minecraft.resource.ResourceManager;
import net.minecraft.resource.ResourceType;
import net.minecraft.util.Identifier;
import org.jetbrains.annotations.Nullable;
import org.lwjgl.glfw.GLFW;

public class FabricaaClient implements ClientModInitializer {
    private static final String MODID = "fabricaa";
    // Must match assets/<MODID>/shaders/post/fxaa.json
    private static final Identifier FXAA_ID = Identifier.of(MODID, "shaders/post/fxaa.json");

    private static boolean enabled = true;
    private static @Nullable PostEffectProcessor FXAA;

    private KeyBinding toggleKey;

    @Override
    public void onInitializeClient() {
        // Keybind: F9 to toggle FXAA on/off
        toggleKey = KeyBindingHelper.registerKeyBinding(new KeyBinding(
                "key." + MODID + ".toggle_fxaa",
                InputUtil.Type.KEYSYM,
                GLFW.GLFW_KEY_F9,
                "key.categories.graphics"
        ));

        // Recreate the post-chain on resource reloads (e.g., F3+T)
        ResourceManagerHelper.get(ResourceType.CLIENT_RESOURCES)
                .registerReloadListener(new SimpleSynchronousResourceReloadListener() {
                    @Override public Identifier getFabricId() { return Identifier.of(MODID, "reload"); }
                    @Override public void reload(ResourceManager manager) {
                        var mc = MinecraftClient.getInstance();
                        FXAA = null;
                        try {
                            // Builds from assets/<MODID>/shaders/post/fxaa.json
                            FXAA = new PostEffectProcessor(mc.getTextureManager(), manager, mc.getFramebuffer(), FXAA_ID);
                        } catch (Exception e) {
                            System.err.println("[" + MODID + "] FXAA init failed: " + e);
                        }
                    }
                });

        // Apply the post-pass at the end of world rendering (when enabled)
        WorldRenderEvents.END.register(ctx -> {
            if (!enabled || FXAA == null) return;
            var mc = MinecraftClient.getInstance();
            var fb = mc.getFramebuffer();

            int w = mc.getFramebuffer().textureWidth;
            int h = mc.getFramebuffer().textureHeight;
            if (w <= 0 || h <= 0) return;

            // Ensure dimensions are correct (handles resizes/alt-tab)
            FXAA.setupDimensions(w, h);
            FXAA.render(ctx.tickCounter().getTickDelta(false));
            fb.beginWrite(false);
        });

        // Toggle handler
        ClientTickEvents.END_CLIENT_TICK.register(client -> {
            while (toggleKey.wasPressed()) {
                enabled = !enabled;

                // Log current state
                System.out.println("[" + MODID + "] FXAA is " + (enabled ? "enabled" : "disabled"));

                if (enabled) rebuildFxaa();

                MinecraftClient.getInstance().reloadResources();
            }
        });
        
    }

    private static void rebuildFxaa() {
        var mc = MinecraftClient.getInstance();
        FXAA = null;
        try {
            FXAA = new PostEffectProcessor(
                    mc.getTextureManager(),
                    mc.getResourceManager(),          // current manager (no F3+T needed)
                    mc.getFramebuffer(),
                    Identifier.of(MODID, "shaders/post/fxaa.json")
            );
            FXAA.setupDimensions(
                    mc.getWindow().getFramebufferWidth(),
                    mc.getWindow().getFramebufferHeight()
            );
        } catch (Exception e) {
            System.err.println("[" + MODID + "] FXAA init failed: " + e);
        }
    }
}