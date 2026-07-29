# Fluent UI v9 Conventions

> Fluent UI v9 requires React 18 — pin `react`, `react-dom`, and their `@types`
> packages to 18.x in every app that uses it (`samples/FluentSample` is the
> reference pairing). The scaffold templates ship React 19, so downgrade first.

## DataGrid — non-negotiable

1. **Server-side only.** Never implement client-side sorting with compare
   functions.
2. **Both views.** Desktop table *and* mobile card layout, always.
3. **Skeletons, not spinners,** for every loading state.
4. **Column resizing** via `columnSizingOptions` with explicit width
   constraints.
5. **Reset to page 1** whenever sort or filter params change.
6. **ARIA labels and keyboard navigation** on every grid.

## Component patterns

- `makeStyles` with design tokens for all styling.
- `useMemo` for column definitions — prevents re-render churn.
- `useEffect` for data loading on parameter changes; correct dependency arrays.
- Handle loading, error, and empty states explicitly.
- Typed interfaces everywhere.

## Accessibility

- `aria-label` or `aria-labelledby` on every interactive element;
  `aria-describedby` for extra context.
- Semantic HTML first, ARIA second.
- Managed focus and deliberate tab order via `tabIndex`.
- Arrow-key navigation within grids; skip links for long content.
- Contrast: 4.5:1 normal text, 3:1 large text. Use Fluent design tokens.
- Never convey information by color alone.

## Responsive

- Mobile-first, then enhance upward using Fluent's breakpoints.
- Touch targets 44px minimum.
- CSS Grid and Flexbox; relative units (rem/em/%) over fixed pixels.
- Correct viewport meta tag.
- Alternative layouts per screen size; compound components for complex cases.
- Deliberate overflow handling and content hierarchy on small screens.

## Performance

- `useMemo` / `useCallback` for expensive computations.
- `React.memo` on components that re-render needlessly.
- Stable `key` props on lists.
- Server-side pagination for large datasets.
- Error boundaries around data-loading regions.
- Cache API responses where it makes sense.
- Dynamic imports for code splitting; rely on Vite's tree shaking and asset
  optimization.

## Reference

- [Fluent UI v9 component docs](https://react.fluentui.dev/)
- [DataGrid patterns in this repo](../samples/FluentSample/)
- [Resizable columns example](https://github.com/microsoft/fluentui/blob/938a069ea4e0c460050e0dc147b9786e144cb6d3/packages/react-components/react-table/stories/src/DataGrid/ResizableColumns.stories.tsx)
