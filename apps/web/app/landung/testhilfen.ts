import { vi } from "vitest";

/**
 * jsdom kennt weder IntersectionObserver noch matchMedia. Die Attrappe
 * merkt sich jeden Observer, damit ein Test gezielt "Element X schneidet
 * jetzt" melden kann -- die Bausteine reagieren auf nichts anderes.
 */
export function stubIntersectionObserver() {
  const alle: FakeIO[] = [];
  class FakeIO {
    ziele = new Set<Element>();
    callback: IntersectionObserverCallback;
    optionen: IntersectionObserverInit | undefined;
    constructor(callback: IntersectionObserverCallback, optionen?: IntersectionObserverInit) {
      this.callback = callback;
      this.optionen = optionen;
      alle.push(this);
    }
    observe(el: Element) {
      this.ziele.add(el);
    }
    unobserve(el: Element) {
      this.ziele.delete(el);
    }
    disconnect() {
      this.ziele.clear();
    }
    takeRecords() {
      return [];
    }
  }
  vi.stubGlobal("IntersectionObserver", FakeIO);
  return {
    melden(ziel: Element, teil: Partial<IntersectionObserverEntry>) {
      for (const io of alle) {
        if (!io.ziele.has(ziel)) continue;
        const eintrag = {
          target: ziel,
          isIntersecting: false,
          boundingClientRect: ziel.getBoundingClientRect(),
          ...teil,
        } as IntersectionObserverEntry;
        io.callback([eintrag], io as unknown as IntersectionObserver);
      }
    },
  };
}

export function stubMatchMedia(treffer: (query: string) => boolean) {
  vi.stubGlobal("matchMedia", (query: string) => ({
    matches: treffer(query),
    media: query,
    onchange: null,
    addEventListener() {},
    removeEventListener() {},
    addListener() {},
    removeListener() {},
    dispatchEvent: () => false,
  }));
}
