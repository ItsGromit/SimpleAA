package com.github.itsgromit.fabricaa.client;

import org.lwjgl.opengl.*;

/**
 * Multisampled offscreen target (sRGB color + depth-stencil) with resolve().
 * No RenderSystem dependency to keep it minimal.
 */
public final class MSAAFramebuffer {
    private int fbo = 0;
    private int colorRbo = 0;
    private int depthRbo = 0;
    private int width = 0, height = 0;
    private int samples = 0;

    public void create(int width, int height, int samples) {
        destroy();
        this.width = Math.max(1, width);
        this.height = Math.max(1, height);
        this.samples = Math.max(2, samples);

        fbo = GL30.glGenFramebuffers();
        GL30.glBindFramebuffer(GL30.GL_FRAMEBUFFER, fbo);

        // ---- COLOR (sRGB) ----
        colorRbo = GL30.glGenRenderbuffers();
        GL30.glBindRenderbuffer(GL30.GL_RENDERBUFFER, colorRbo);

        // Use SRGB for proper color space handling
        GL30.glRenderbufferStorageMultisample(
                GL30.GL_RENDERBUFFER, this.samples,
                GL21.GL_SRGB8_ALPHA8,
                this.width, this.height
        );
        GL30.glFramebufferRenderbuffer(
                GL30.GL_FRAMEBUFFER, GL30.GL_COLOR_ATTACHMENT0,
                GL30.GL_RENDERBUFFER, colorRbo
        );

        // ---- DEPTH+STENCIL ----
        depthRbo = GL30.glGenRenderbuffers();
        GL30.glBindRenderbuffer(GL30.GL_RENDERBUFFER, depthRbo);
        GL30.glRenderbufferStorageMultisample(
                GL30.GL_RENDERBUFFER, this.samples,
                GL30.GL_DEPTH24_STENCIL8,
                this.width, this.height
        );
        GL30.glFramebufferRenderbuffer(
                GL30.GL_FRAMEBUFFER, GL30.GL_DEPTH_STENCIL_ATTACHMENT,
                GL30.GL_RENDERBUFFER, depthRbo
        );

        // Select our only color attachment for draw+read
        GL20.glDrawBuffers(new int[]{GL30.GL_COLOR_ATTACHMENT0});
        GL11.glReadBuffer(GL30.GL_COLOR_ATTACHMENT0);

        int status = GL30.glCheckFramebufferStatus(GL30.GL_FRAMEBUFFER);
        if (status != GL30.GL_FRAMEBUFFER_COMPLETE) {
            throw new IllegalStateException("MSAA FBO incomplete: 0x" + Integer.toHexString(status));
        }

        // Cleanup binds
        GL30.glBindRenderbuffer(GL30.GL_RENDERBUFFER, 0);
        GL30.glBindFramebuffer(GL30.GL_FRAMEBUFFER, 0);
    }

    /** Bind and clear for initial world rendering (call once per frame). */
    public void bindAndClear() {
        GL30.glBindFramebuffer(GL30.GL_FRAMEBUFFER, fbo);
        GL11.glViewport(0, 0, width, height);
        // Clear with proper alpha
        GL11.glClearColor(0f, 0f, 0f, 1f);
        GL11.glClearDepth(1.0);
        GL11.glClear(GL11.GL_COLOR_BUFFER_BIT | GL11.GL_DEPTH_BUFFER_BIT | GL11.GL_STENCIL_BUFFER_BIT);
        GL11.glEnable(GL13.GL_MULTISAMPLE);
        GL11.glEnable(GL11.GL_DEPTH_TEST);

        // Slight polygon offset to reduce texture atlas bleeding
        GL11.glEnable(GL11.GL_POLYGON_OFFSET_FILL);
        GL11.glPolygonOffset(0.0f, -0.5f);
    }

    /** Bind for world rendering WITHOUT clearing (for subsequent render passes). */
    public void bindForRender() {
        GL30.glBindFramebuffer(GL30.GL_FRAMEBUFFER, fbo);
        GL11.glViewport(0, 0, width, height);
        GL11.glEnable(GL13.GL_MULTISAMPLE);

        // Slight polygon offset to reduce texture atlas bleeding
        GL11.glEnable(GL11.GL_POLYGON_OFFSET_FILL);
        GL11.glPolygonOffset(0.0f, -0.5f);
    }

    /** Resolve MSAA color into the currently bound DRAW FBO. */
    public void resolveToCurrentlyBoundDrawFbo() {
        // Source (READ): our multisampled FBO
        GL30.glBindFramebuffer(GL30.GL_READ_FRAMEBUFFER, fbo);
        GL11.glReadBuffer(GL30.GL_COLOR_ATTACHMENT0);

        // Destination (DRAW): whatever is currently bound (window FBO after beginWrite(false))
        int drawFbo = GL11.glGetInteger(GL30.GL_DRAW_FRAMEBUFFER_BINDING);
        GL30.glBindFramebuffer(GL30.GL_DRAW_FRAMEBUFFER, drawFbo);
        GL11.glDrawBuffer(drawFbo == 0 ? GL11.GL_BACK : GL30.GL_COLOR_ATTACHMENT0);

        // Blit color; MSAA resolves must use NEAREST
        GL30.glBlitFramebuffer(
                0, 0, width, height,
                0, 0, width, height,
                GL11.GL_COLOR_BUFFER_BIT,
                GL11.GL_NEAREST
        );

        // Also blit depth to maintain proper depth testing for GUI elements
        GL30.glBlitFramebuffer(
                0, 0, width, height,
                0, 0, width, height,
                GL11.GL_DEPTH_BUFFER_BIT,
                GL11.GL_NEAREST
        );

        GL30.glBindFramebuffer(GL30.GL_FRAMEBUFFER, drawFbo);
    }

    public void destroy() {
        if (depthRbo != 0) { GL30.glDeleteRenderbuffers(depthRbo); depthRbo = 0; }
        if (colorRbo != 0) { GL30.glDeleteRenderbuffers(colorRbo); colorRbo = 0; }
        if (fbo != 0) { GL30.glDeleteFramebuffers(fbo); fbo = 0; }
    }

    public int width() { return width; }
    public int height() { return height; }
    public int samples() { return samples; }
}