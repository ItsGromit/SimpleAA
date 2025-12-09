package com.github.itsgromit.fabricaa.client;

import net.fabricmc.api.ClientModInitializer;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.fabricmc.fabric.api.client.keybinding.v1.KeyBindingHelper;
import net.fabricmc.fabric.api.resource.ResourceManagerHelper;
import net.fabricmc.fabric.api.resource.SimpleSynchronousResourceReloadListener;

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

    // Post chain JSONs
    private static final Identifier FXAA_ID = Identifier.of(MODID, "shaders/post/fxaa.json");
    private static final Identifier SMAA_ID = Identifier.of(MODID, "shaders/post/smaa.json");

    private enum AAMode { OFF, FXAA, SMAA }

    private static AAMode mode = AAMode.FXAA;

    private static @Nullable PostEffectProcessor FXAA;
    private static @Nullable PostEffectProcessor SMAA;

    // Track last known resolution to detect changes
    private static int lastWidth = -1;
    private static int lastHeight = -1;

    private KeyBinding toggleKey;

    @Override
    public void onInitializeClient() {
        // Keybind: F9 to cycle through AA modes (OFF -> FXAA -> SMAA)
        toggleKey = KeyBindingHelper.registerKeyBinding(new KeyBinding(
                "key." + MODID + ".toggle_aa",
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
                        SMAA = null;

                        try {
                            FXAA = new PostEffectProcessor(mc.getTextureManager(), manager, mc.getFramebuffer(), FXAA_ID);
                        } catch (Exception e) {
                            System.err.println("[" + MODID + "] FXAA init failed: " + e);
                        }
                        try {
                            SMAA = new PostEffectProcessor(mc.getTextureManager(), manager, mc.getFramebuffer(), SMAA_ID);
                        } catch (Exception e) {
                            System.err.println("[" + MODID + "] SMAA init failed: " + e);
                        }
                    }
                });

        // Keybind tick handler
        ClientTickEvents.END_CLIENT_TICK.register(client -> {
            while (toggleKey.wasPressed()) {
                mode = next(mode);
                System.out.println("[" + MODID + "] AA mode: " + mode);

                ensureBuilt(mode);
            }
        });
    }

    public static void applyPostProcessing(float tickDelta) {
        var mc = MinecraftClient.getInstance();

        PostEffectProcessor active = switch (mode) {
            case FXAA -> FXAA;
            case SMAA -> SMAA;
            default -> null;
        };
        if (active == null) return;

        // Get actual window dimensions (not GUI-scaled)
        int windowWidth = mc.getWindow().getFramebufferWidth();
        int windowHeight = mc.getWindow().getFramebufferHeight();

        if (windowWidth <= 0 || windowHeight <= 0) return;

        // Detect resolution change and rebuild post-processors if needed
        if (windowWidth != lastWidth || windowHeight != lastHeight) {
            System.out.println("[" + MODID + "] Resolution changed to " + windowWidth + "x" + windowHeight + ", rebuilding post-processors");
            lastWidth = windowWidth;
            lastHeight = windowHeight;

            // Rebuild post-processors at the new resolution
            FXAA = null;
            SMAA = null;
            ensureBuilt(mode);

            // Update the active reference after rebuild
            active = switch (mode) {
                case FXAA -> FXAA;
                case SMAA -> SMAA;
                default -> null;
            };
            if (active == null) return;
        }

        // Apply AA effect directly to the main framebuffer
        active.setupDimensions(windowWidth, windowHeight);
        active.render(tickDelta);
    }

    private static AAMode next(AAMode m) {
        return switch (m) {
            case OFF -> AAMode.FXAA;
            case FXAA -> AAMode.SMAA;
            case SMAA -> AAMode.OFF;
        };
    }

    private static void ensureBuilt(AAMode m) {
        var mc = MinecraftClient.getInstance();
        // Use actual window dimensions, not framebuffer texture size
        int windowWidth = mc.getWindow().getFramebufferWidth();
        int windowHeight = mc.getWindow().getFramebufferHeight();

        try {
            switch (m) {
                case FXAA -> {
                    if (FXAA == null) {
                        FXAA = new PostEffectProcessor(
                                mc.getTextureManager(),
                                mc.getResourceManager(),
                                mc.getFramebuffer(),
                                FXAA_ID
                        );
                        FXAA.setupDimensions(windowWidth, windowHeight);
                    }
                }
                case SMAA -> {
                    if (SMAA == null) {
                        SMAA = new PostEffectProcessor(
                                mc.getTextureManager(),
                                mc.getResourceManager(),
                                mc.getFramebuffer(),
                                SMAA_ID
                        );
                        SMAA.setupDimensions(windowWidth, windowHeight);
                    }
                }
                case OFF -> { /* nothing */ }
            }
        } catch (Exception e) {
            System.err.println("[" + MODID + "] " + m + " init failed: " + e);
        }
    }
}